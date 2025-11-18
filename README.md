## 🎫 Event Ticket Booking System

This is a full-stack web application designed to manage events, ticket sales, and customer bookings, built using a robust MySQL backend and a Python Flask API.

### ✨ Key Features Implemented

The project demonstrates advanced Database Management System (DBMS) concepts to ensure data integrity and complex business logic:

  * **Transactional Booking Logic:** Handled via the **`BookTicket` Stored Procedure**, ensuring atomic operations (creating ticket and payment records).
  * **Inventory Management:** **Triggers** automatically decrement seat counts (`Available_Seats`) upon booking and restore seats upon cancellation.
  * **Data Integrity & Validation:** **Triggers** enforce rules like preventing bookings for past events, enforcing a 5-ticket per event limit per customer, and validating customer email formats.
  * **Reporting:** Advanced queries using **Window Functions** (`RANK() OVER...`) are used to generate reports like Top Customer Spending Ranks.
  * **Specialization/Generalization:** The database uses an inheritance structure to handle different event types (`Movie`, `Concert`, `Cricket_Match`).

-----

## 💻 Project Setup & Installation

Follow these steps to get the application running locally.

### 1\. Prerequisites

You must have the following software installed:

  * **MySQL Server** (or a local environment like XAMPP/WAMP/MAMP)
  * **Python 3.x**
  * **Web Browser** (Chrome/Firefox)

### 2\. Database Setup

1.  **Run the SQL Script:** Execute the entire project SQL file (containing all `CREATE TABLE`, `INSERT DATA`, `CREATE FUNCTION`, `CREATE PROCEDURE`, and `CREATE TRIGGER` statements) in your MySQL client (e.g., MySQL Workbench). This creates the `EventTicketBooking` database and populates it with initial data.

2.  **Update Credentials:** Open the Python file (`app.py`) and update the `DB_CONFIG` dictionary with your actual MySQL username and password:

    ```python
    DB_CONFIG = {
        'host': 'localhost',
        'user': 'your_mysql_user',  # <-- Change this
        'password': 'your_mysql_password', # <-- Change this
        'database': 'EventTicketBooking'
    }
    ```

### 3\. Python Environment

1.  **Install Dependencies:** Open your terminal and install the required Python libraries:

    ```bash
    pip install Flask mysql-connector-python flask-cors
    ```

2.  **File Structure:** Ensure your files are arranged correctly:

    ```
    /project_root
    |-- app.py             <-- Flask API (main entry point)
    |-- templates/
    |   |-- index.html     <-- Frontend UI
    |-- Event_Ticket_Booking.sql    <-- (The comprehensive SQL file)
    ```

### 4\. Run the Application

1.  **Start Flask Server:** In the terminal, navigate to the project root and run:

    ```bash
    python app.py
    ```

    The server will start at `http://127.0.0.1:5000`.

2.  **Access the UI:** Open your web browser and navigate to:

    ```
    http://127.0.0.1:5000
    ```

-----

## 🛠️ Usage and Testing

### Testing Credentials

You can use the following sample data (inserted via the SQL script) to test the login feature:

| Name | Email |
| :--- | :--- |
| **Alice Johnson** | `alice@example.com` |
| **Bob Smith** | `bob@example.com` |
| **Carol Senior** | `carol@example.com` |

### Key API Endpoints

The frontend communicates with the following endpoints:

| Endpoint | Method | Function | DBMS Concept Tested |
| :--- | :--- | :--- | :--- |
| `/login` | `POST` | Authenticate customer by email. | Simple SELECT query |
| `/events` | `GET` | Retrieve list of all upcoming events. | Complex JOINs, Date/Time comparison |
| `/book-ticket` | `POST` | Process ticket purchase. | **Stored Procedure (`BookTicket`), Triggers (`BeforeTicketInsert`, `AfterTicketInsert`)** |
| `/my-bookings` | `GET` | Fetch all tickets for the logged-in user. | Complex JOINs |
| `/reports/top-customers` | `GET` | Generate spending rank report. | **Window Function (`RANK()`)** |


In short,

Step 1: On MySQL command prompt, run source path to your Event_Ticket_Booking.sql
Make sure to change 'password' to your database password
All tables are created with some records inserted
Triggers, Procedures and Functions implemented

Step 2: Run python app.py, which is a Flask App running on localhost
SQL Queries can be executed by connecting the python code to the database using mysql-connector-python

