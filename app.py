from flask import Flask, render_template, request, jsonify, session, redirect, url_for
import mysql.connector
from mysql.connector import Error # Import Error for cleaner exception handling
import secrets
import re
from datetime import date, datetime, timedelta # Import date/time types for conversion

app = Flask(__name__)
app.secret_key = secrets.token_hex(16)

DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': 'password', 
    'database': 'EventTicketBooking'
}

def get_db():
    """Establishes database connection."""
    try:
        return mysql.connector.connect(**DB_CONFIG)
    except Error as err:
        print(f"Database Connection Error: {err}")
        return None

def db_fetch_and_convert(query, params=None):
    """Executes query, fetches all results, and converts problematic types for JSON."""
    conn = get_db()
    if not conn: return []

    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute(query, params or ())
        results = cursor.fetchall()
        
        # JSON Serialization Fix: Convert date/time/decimal objects to string/float
        cleaned_results = []
        for row in results:
            cleaned_row = {}
            for key, value in row.items():
                if isinstance(value, (date, datetime, timedelta)):
                    cleaned_row[key] = str(value)
                elif value is not None and (key.lower().endswith('price') or key.lower().endswith('revenue') or key.lower().endswith('spent') or key.lower().endswith('percentage')):
                    cleaned_row[key] = float(value)
                else:
                    cleaned_row[key] = value
            cleaned_results.append(cleaned_row)
            
        return cleaned_results
    except Error as err:
        print(f"Query Execution Error: {err}")
        return []
    finally:
        if conn and conn.is_connected():
            conn.close()

# ----------------------------------------------------------------------
# Core Routes
# ----------------------------------------------------------------------

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/login', methods=['POST'])
def login():
    data = request.json
    email = data.get('email', '').strip()
    
    conn = get_db()
    if not conn:
        return jsonify({'success': False, 'message': 'Database connection failed'})
    
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT Cust_ID, Cust_Name, Email FROM Customer WHERE Email = %s", (email,))
    user = cursor.fetchone()
    conn.close()
    
    if user:
        session['user'] = {
            'id': user['Cust_ID'],
            'name': user['Cust_Name'],
            'email': user['Email']
        }
        return jsonify({'success': True, 'message': f'Welcome back, {user["Cust_Name"]}!', 'user': session['user']})
    else:
        return jsonify({'success': False, 'message': 'Email not found. Please register first.'})

@app.route('/register', methods=['POST'])
def register():
    data = request.json
    name = data.get('name', '').strip()
    email = data.get('email', '').strip()
    phone = data.get('phone', '').strip()
    dob = data.get('dob', '').strip()
    gender = data.get('gender', '')
    address = data.get('address', '').strip()
    
    if not all([name, email, phone]):
        return jsonify({'success': False, 'message': 'Name, Email, and Phone are required'})
    
    conn = get_db()
    if not conn:
        return jsonify({'success': False, 'message': 'Database connection failed'})
    
    try:
        cursor = conn.cursor()
        query = """INSERT INTO Customer (Cust_Name, Email, Phone, DOB, Gender, Address) 
                   VALUES (%s, %s, %s, %s, %s, %s)"""
        
        # Executes the query, activating the BEFORE INSERT trigger (ValidateCustomerEmail)
        cursor.execute(query, (name, email, phone, dob if dob else None, 
                               gender if gender else None, address if address else None))
        conn.commit()
        conn.close()
        return jsonify({'success': True, 'message': 'Registration successful! Please login.'})
    except Error as err:
        conn.close()
        # Catches custom SIGNAL SQLSTATE '45000' from the trigger or UNIQUE constraint errors
        return jsonify({'success': False, 'message': f'Registration failed: {str(err)}'})

@app.route('/logout')
def logout():
    session.pop('user', None)
    return jsonify({'success': True})

# ----------------------------------------------------------------------
# Event and Booking API
# ----------------------------------------------------------------------

@app.route('/events')
def get_events():
    event_type = request.args.get('type', 'All')
    city = request.args.get('city', '').strip()
    
    query = """
    SELECT e.Event_ID, e.Event_Type, e.Event_Date, e.Event_Time, 
            e.Duration, e.No_of_Seats, v.Venue_Name, v.City,
            COALESCE(m.Movie_Name, c.Artist_Name, 
                     CONCAT(cr.Team1_Name, ' vs ', cr.Team2_Name), 
                     sc.Comedian_Name) AS Event_Name,
            COALESCE(m.Genre, c.Music_Genre, cr.Match_Type, sc.Comedy_Style, '') AS Extra_Info
    FROM Event e
    JOIN Venue v ON e.Venue_ID = v.Venue_ID
    LEFT JOIN Movie m ON e.Event_ID = m.Event_ID
    LEFT JOIN Concert c ON e.Event_ID = c.Event_ID
    LEFT JOIN Cricket_Match cr ON e.Event_ID = cr.Event_ID
    LEFT JOIN Standup_Comedy sc ON e.Event_ID = sc.Event_ID
    WHERE e.Event_Date >= CURDATE()
    """
    
    params = []
    if event_type != 'All':
        query += " AND e.Event_Type = %s"
        params.append(event_type)
    
    if city:
        query += " AND v.City LIKE %s"
        params.append(f"%{city}%")
    
    query += " ORDER BY e.Event_Date, e.Event_Time"
    
    events = db_fetch_and_convert(query, params)
    
    return jsonify({'success': True, 'events': events})

@app.route('/event/<int:event_id>/categories')
def get_event_categories(event_id):
    query = """
        SELECT Category_Name, Available_Seats, Status,
                (Base_Price * Price_Multiplier) AS Final_Price
        FROM Seat_Category
        WHERE Event_ID = %s
        ORDER BY Final_Price DESC
    """
    categories = db_fetch_and_convert(query, (event_id,))
    
    if not categories:
        return jsonify({'success': False, 'message': 'No categories found'})
        
    return jsonify({'success': True, 'categories': categories})


@app.route('/book-ticket', methods=['POST'])
def book_ticket():
    if 'user' not in session:
        return jsonify({'success': False, 'message': 'Authentication failed. Please login.'})
    
    data = request.json
    cust_id = session['user']['id']
    event_id = data.get('event_id')
    category = data.get('category')
    seat_no = data.get('seat_no', '').strip()
    payment_mode = data.get('payment_mode')
    
    conn = get_db()
    if not conn:
        return jsonify({'success': False, 'message': 'Database connection failed'})
    
    try:
        cursor = conn.cursor()
        # Call the Stored Procedure (Activates BeforeTicketInsert and AfterTicketInsert triggers)
        cursor.callproc('BookTicket', [
            cust_id,
            int(event_id),
            category,
            seat_no,
            payment_mode
        ])
        conn.commit()
        conn.close()
        return jsonify({'success': True, 'message': f'Ticket booked successfully! Seat: {seat_no}'})
    except Error as err:
        conn.close()
        # Catches the custom SIGNAL SQLSTATE '45000' messages from the triggers/procedures
        error_message = str(err).split(':')[-1].strip()
        return jsonify({'success': False, 'message': f'Booking failed: {error_message}'})


@app.route('/my-bookings')
def get_my_bookings():
    if 'user' not in session:
        return jsonify({'success': False, 'message': 'Please login first'})
    
    cust_id = session['user']['id']
    
    query = """
        SELECT t.Ticket_No, t.Booking_Date, t.Seat_No, t.Final_Price, t.Status, t.Event_ID,
                sc.Category_Name, p.Payment_Status,
                COALESCE(m.Movie_Name, c.Artist_Name, 
                         CONCAT(cr.Team1_Name, ' vs ', cr.Team2_Name), 
                         sc_comedy.Comedian_Name) AS Event_Name,
                e.Event_Date, v.Venue_Name
        FROM Ticket t
        JOIN Event e ON t.Event_ID = e.Event_ID
        JOIN Seat_Category sc ON t.Category_ID = sc.Category_ID
        JOIN Venue v ON e.Venue_ID = v.Venue_ID
        LEFT JOIN Payment p ON t.Ticket_No = p.Ticket_No
        LEFT JOIN Movie m ON e.Event_ID = m.Event_ID
        LEFT JOIN Concert c ON e.Event_ID = c.Event_ID
        LEFT JOIN Cricket_Match cr ON e.Event_ID = cr.Event_ID
        LEFT JOIN Standup_Comedy sc_comedy ON e.Event_ID = sc_comedy.Event_ID
        WHERE t.Cust_ID = %s
        ORDER BY t.Booking_Date DESC
    """
    bookings = db_fetch_and_convert(query, (cust_id,))
    
    return jsonify({'success': True, 'bookings': bookings})


# ----------------------------------------------------------------------
# MISSING OPERATION 1: Ticket Cancellation (Demonstrates Trigger 7.4)
# ----------------------------------------------------------------------
@app.route('/cancel-ticket/<int:ticket_no>', methods=['POST'])
def cancel_ticket(ticket_no):
    if 'user' not in session:
        return jsonify({'success': False, 'message': 'Authentication failed. Please login.'})
    
    # FIX: Define the cust_id variable right here by pulling it from the session.
    # This line was missing or misplaced in your code block.
    cust_id = session['user']['id'] 
    
    conn = get_db()
    if not conn:
        return jsonify({'success': False, 'message': 'Database connection failed'})
    
    try:
        # NOTE: Using dictionary=True is crucial to access results with string keys like ['Cust_ID']
        cursor = conn.cursor(dictionary=True) 
        
        # Find the ticket and check ownership/status
        cursor.execute("SELECT Status, Cust_ID FROM Ticket WHERE Ticket_No = %s", (ticket_no,))
        ticket = cursor.fetchone()
        
        if not ticket:
            conn.close()
            return jsonify({'success': False, 'message': 'Ticket not found.'})
        
        if ticket['Cust_ID'] != cust_id: # This line now has a defined 'cust_id' to check against
            conn.close()
            return jsonify({'success': False, 'message': 'Permission denied.'})

        if ticket['Status'] == 'Canceled':
            conn.close()
            return jsonify({'success': False, 'message': 'Ticket is already canceled.'})
            
        # Update status to 'Canceled' (Activates AfterTicketCancellation trigger 7.4)
        update_query = "UPDATE Ticket SET Status = 'Canceled' WHERE Ticket_No = %s"
        cursor.execute(update_query, (ticket_no,))
        conn.commit()
        
        conn.close()
        return jsonify({'success': True, 'message': f'Ticket {ticket_no} successfully canceled. Seats and payment updated.'})
        
    except Error as err:
        conn.close()
        return jsonify({'success': False, 'message': f'Cancellation failed: {str(err)}'})

# ----------------------------------------------------------------------
# MISSING OPERATION 2: Scalar Function Demonstration (CalculateAge)
# ----------------------------------------------------------------------
@app.route('/reports/customer-age')
def get_customer_age():
    if 'user' not in session:
        return jsonify({'success': False, 'message': 'Please login.'})
        
    cust_id = session['user']['id']
    query = "SELECT Cust_Name, DOB, CalculateAge(DOB) AS Age FROM Customer WHERE Cust_ID = %s"
    results = db_fetch_and_convert(query, (cust_id,))
    
    if results and results[0]['DOB']:
        return jsonify({'success': True, 'data': results[0]})
    elif results:
        return jsonify({'success': False, 'message': 'Date of Birth not recorded for age calculation.'})
    else:
        return jsonify({'success': False, 'message': 'Customer not found.'})

# ----------------------------------------------------------------------
# Report Routes
# ----------------------------------------------------------------------

@app.route('/reports/revenue')
def revenue_report():
    query = """
        SELECT e.Event_ID, e.Event_Type, 
               COALESCE(m.Movie_Name, c.Artist_Name, 
                         CONCAT(cr.Team1_Name, ' vs ', cr.Team2_Name), 
                         sc.Comedian_Name) AS Event_Name,
               COUNT(t.Ticket_No) AS Tickets_Sold,
               COALESCE(SUM(t.Final_Price), 0) AS Total_Revenue
        FROM Event e
        LEFT JOIN Ticket t ON e.Event_ID = t.Event_ID AND t.Status = 'Booked'
        LEFT JOIN Movie m ON e.Event_ID = m.Event_ID
        LEFT JOIN Concert c ON e.Event_ID = c.Event_ID
        LEFT JOIN Cricket_Match cr ON e.Event_ID = cr.Event_ID
        LEFT JOIN Standup_Comedy sc ON e.Event_ID = sc.Event_ID
        GROUP BY e.Event_ID
        ORDER BY Total_Revenue DESC
        LIMIT 20
    """
    results = db_fetch_and_convert(query)
    return jsonify({'success': True, 'data': results})

@app.route('/reports/top-customers')
def top_customers_report():
    query = """
        WITH CustomerTotalSpent AS (
            SELECT Cust_ID, SUM(Final_Price) AS Total_Spent
            FROM Ticket
            WHERE Status = 'Booked'
            GROUP BY Cust_ID
        )
        SELECT c.Cust_Name, c.Email, CTS.Total_Spent,
                RANK() OVER (ORDER BY CTS.Total_Spent DESC) AS Spending_Rank
        FROM Customer c
        JOIN CustomerTotalSpent CTS ON c.Cust_ID = CTS.Cust_ID
        ORDER BY Spending_Rank
        LIMIT 15
    """
    results = db_fetch_and_convert(query)
    return jsonify({'success': True, 'data': results})

if __name__ == '__main__':
    # Ensure you are running this from a directory that contains a 'templates' folder with index.html
    app.run(debug=True, port=5000)