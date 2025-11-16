--
-- 1. DATABASE CREATION
--
CREATE DATABASE EventTicketBooking;
USE EventTicketBooking;

--
-- 2. TABLE CREATION (ENTITIES)
--

-- Table: Customer
CREATE TABLE Customer (
    Cust_ID INT PRIMARY KEY AUTO_INCREMENT,
    Cust_Name VARCHAR(100) NOT NULL,
    DOB DATE,
    Gender ENUM('Male', 'Female', 'Other'),
    Email VARCHAR(100) UNIQUE NOT NULL,
    Phone VARCHAR(15),
    Address VARCHAR(255),
    Registration_Date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Venue
CREATE TABLE Venue (
    Venue_ID INT PRIMARY KEY AUTO_INCREMENT,
    Venue_Name VARCHAR(100) NOT NULL,
    Address VARCHAR(255),
    City VARCHAR(50),
    Facilities TEXT,
    Capacity INT
);

-- Table: Event (Parent table)
CREATE TABLE Event (
    Event_ID INT PRIMARY KEY AUTO_INCREMENT,
    Event_Type VARCHAR(50) NOT NULL, -- e.g., 'Movie', 'Concert', 'Cricket_Match'
    Event_Date DATE NOT NULL,
    Event_Time TIME,
    No_of_Seats INT NOT NULL,
    Duration TIME,
    Venue_ID INT NOT NULL,
    FOREIGN KEY (Venue_ID) REFERENCES Venue(Venue_ID)
);

-- Table: Seat_Category (Weak Entity of Event)
CREATE TABLE Seat_Category (
    Category_ID INT PRIMARY KEY AUTO_INCREMENT,
    Event_ID INT NOT NULL,
    Category_Name VARCHAR(50) NOT NULL,
    Status ENUM('Available', 'Sold Out') NOT NULL DEFAULT 'Available',
    Base_Price DECIMAL(10, 2) NOT NULL,
    Available_Seats INT NOT NULL,
    Price_Multiplier DECIMAL(5, 2) NOT NULL,
    FOREIGN KEY (Event_ID) REFERENCES Event(Event_ID),
    UNIQUE KEY (Event_ID, Category_Name) -- Unique category name per event
);

-- Table: Ticket (Junction/Relationship table for Customer-Event and holds booking details)
CREATE TABLE Ticket (
    Ticket_No INT PRIMARY KEY AUTO_INCREMENT,
    Event_ID INT NOT NULL,
    Cust_ID INT NOT NULL,
    Seat_No VARCHAR(10),
    Booking_Date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Status ENUM('Booked', 'Canceled') NOT NULL DEFAULT 'Booked',
    Final_Price DECIMAL(10, 2),
    Category_ID INT, -- Linking ticket to a specific price/seat category
    FOREIGN KEY (Event_ID) REFERENCES Event(Event_ID),
    FOREIGN KEY (Cust_ID) REFERENCES Customer(Cust_ID),
    FOREIGN KEY (Category_ID) REFERENCES Seat_Category(Category_ID),
    UNIQUE KEY (Event_ID, Seat_No) -- No two tickets for the same seat/event
);

-- Table: Payment
CREATE TABLE Payment (
    Transaction_ID INT PRIMARY KEY AUTO_INCREMENT,
    Ticket_No INT UNIQUE NOT NULL, -- One payment per ticket
    Ticket_Amount DECIMAL(10, 2) NOT NULL,
    Mode_of_Payment VARCHAR(50),
    Payment_Date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Payment_Status ENUM('Successful', 'Pending', 'Failed') NOT NULL,
    FOREIGN KEY (Ticket_No) REFERENCES Ticket(Ticket_No)
);


--
-- 3. SPECIALIZED EVENT TABLES (INHERITANCE)
--

-- Table: Movie
CREATE TABLE Movie (
    Event_ID INT PRIMARY KEY,
    Movie_Name VARCHAR(100) NOT NULL,
    Movie_Language VARCHAR(50),
    Genre VARCHAR(50),
    Rating DECIMAL(2, 1),
    Director VARCHAR(100),
    FOREIGN KEY (Event_ID) REFERENCES Event(Event_ID)
);

-- Table: Concert
CREATE TABLE Concert (
    Event_ID INT PRIMARY KEY,
    Artist_Name VARCHAR(100) NOT NULL,
    Music_Genre VARCHAR(50),
    FOREIGN KEY (Event_ID) REFERENCES Event(Event_ID)
);

-- Table: Standup_Comedy
CREATE TABLE Standup_Comedy (
    Event_ID INT PRIMARY KEY,
    Comedian_Name VARCHAR(100) NOT NULL,
    Comedy_Style VARCHAR(50),
    FOREIGN KEY (Event_ID) REFERENCES Event(Event_ID)
);

-- Table: Cricket_Match
CREATE TABLE Cricket_Match (
    Event_ID INT PRIMARY KEY,
    Team1_Name VARCHAR(50) NOT NULL,
    Team2_Name VARCHAR(50) NOT NULL,
    Match_Type VARCHAR(50),
    Tournament_Name VARCHAR(100),
    FOREIGN KEY (Event_ID) REFERENCES Event(Event_ID)
);

-- Table: Customer_Activity_Log (Moved here from the trigger section)
CREATE TABLE Customer_Activity_Log (
    Log_ID INT PRIMARY KEY AUTO_INCREMENT,
    Cust_ID INT NOT NULL,
    Activity_Type VARCHAR(50) NOT NULL,
    Activity_Date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    Details TEXT,
    FOREIGN KEY (Cust_ID) REFERENCES Customer(Cust_ID)
);


--
-- 4. INSERT SAMPLE DATA
--

INSERT INTO Venue (Venue_Name, Address, City, Facilities, Capacity) VALUES
('Grand Arena', '123 Main St', 'New York', 'Parking, Food Court', 10000),
('Cineplex 1', '45 Movie Blvd', 'New York', 'Dolby Atmos', 200);

INSERT INTO Event (Event_Type, Event_Date, Event_Time, No_of_Seats, Duration, Venue_ID) VALUES
('Concert', '2025-12-01', '19:00:00', 8000, '02:30:00', 1),
('Movie', '2025-11-15', '14:00:00', 200, '02:00:00', 2);

INSERT INTO Concert (Event_ID, Artist_Name, Music_Genre) VALUES
(1, 'The Rockers', 'Rock');

INSERT INTO Movie (Event_ID, Movie_Name, Movie_Language, Genre, Rating, Director) VALUES
(2, 'Future Tech', 'English', 'Sci-Fi', 8.5, 'J. Smith');

INSERT INTO Seat_Category (Event_ID, Category_Name, Base_Price, Available_Seats, Price_Multiplier) VALUES
(1, 'VIP', 100.00, 1000, 1.50),
(1, 'General', 50.00, 7000, 1.00),
(2, 'Premium', 12.00, 50, 1.25),
(2, 'Standard', 10.00, 150, 1.00);

INSERT INTO Customer (Cust_Name, Email, Phone, DOB) VALUES
('Alice Johnson', 'alice@example.com', '555-0001', '1990-05-10'),
('Bob Smith', 'bob@example.com', '555-0002', '1985-08-20'),
('Carol Senior', 'carol@example.com', '555-0003', '1955-03-01'); -- For senior discount testing


--
-- 5. SCALAR FUNCTIONS
--

-- Function: Calculate customer age from DOB
DELIMITER //
CREATE FUNCTION CalculateAge(birth_date DATE)
RETURNS INT
DETERMINISTIC
BEGIN
    RETURN TIMESTAMPDIFF(YEAR, birth_date, CURDATE());
END //
DELIMITER ;

-- Function: Get total bookings for an event
DELIMITER //
CREATE FUNCTION GetEventBookingCount(event_id INT)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE booking_count INT;
    
    SELECT COUNT(*) INTO booking_count
    FROM Ticket
    WHERE Event_ID = event_id AND Status = 'Booked';
    
    RETURN booking_count;
END //
DELIMITER ;

-- Function: Calculate venue occupancy percentage
DELIMITER //
CREATE FUNCTION CalculateOccupancy(event_id INT)
RETURNS DECIMAL(5,2)
DETERMINISTIC
BEGIN
    DECLARE total_seats INT;
    DECLARE booked_seats INT;
    DECLARE occupancy DECIMAL(5,2);
    
    SELECT No_of_Seats INTO total_seats
    FROM Event
    WHERE Event_ID = event_id;
    
    SET booked_seats = GetEventBookingCount(event_id);
    
    IF total_seats > 0 THEN
        SET occupancy = (booked_seats / total_seats) * 100;
    ELSE
        SET occupancy = 0;
    END IF;
    
    RETURN occupancy;
END //
DELIMITER ;

-- Function: Calculate final price of a ticket (Original)
DELIMITER //
CREATE FUNCTION CalculateFinalPrice (BasePrice DECIMAL(10, 2), Multiplier DECIMAL(5, 2))
RETURNS DECIMAL(10, 2)
DETERMINISTIC
BEGIN
    RETURN BasePrice * Multiplier;
END //
DELIMITER ;


--
-- 6. STORED PROCEDURE (for Ticket Booking Logic)
--

-- Procedure to handle the transactional logic of booking a ticket
DELIMITER //
CREATE PROCEDURE BookTicket (
    IN p_cust_id INT,
    IN p_event_id INT,
    IN p_category_name VARCHAR(50),
    IN p_seat_no VARCHAR(10),
    IN p_mode_of_payment VARCHAR(50)
)
BEGIN
    DECLARE v_category_id INT;
    DECLARE v_base_price DECIMAL(10, 2);
    DECLARE v_multiplier DECIMAL(5, 2);
    DECLARE v_final_price DECIMAL(10, 2);
    
    -- 1. Find category details
    SELECT Category_ID, Base_Price, Price_Multiplier INTO v_category_id, v_base_price, v_multiplier
    FROM Seat_Category
    WHERE Event_ID = p_event_id AND Category_Name = p_category_name AND Available_Seats > 0
    LIMIT 1;

    -- Check if seat is available and exists
    IF v_category_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Seat category not found or sold out.';
    END IF;

    -- 2. Calculate Final Price using the defined function
    SET v_final_price = CalculateFinalPrice(v_base_price, v_multiplier);

    START TRANSACTION;

    -- 3. Insert into Ticket table (Triggers BEFORE INSERT checks and AFTER INSERT updates)
    INSERT INTO Ticket (Event_ID, Cust_ID, Seat_No, Final_Price, Category_ID)
    VALUES (p_event_id, p_cust_id, p_seat_no, v_final_price, v_category_id);
    
    SET @new_ticket_no = LAST_INSERT_ID();

    -- 4. Insert into Payment table (Triggers AFTER INSERT payment status check)
    INSERT INTO Payment (Ticket_No, Ticket_Amount, Mode_of_Payment, Payment_Status)
    VALUES (@new_ticket_no, v_final_price, p_mode_of_payment, 'Successful');
    
    COMMIT;

END //
DELIMITER ;


--
-- 7. CONSOLIDATED TRIGGERS
--

-- 7.1. TRIGGER: BEFORE INSERT on Customer (Validation)
DELIMITER //
CREATE TRIGGER ValidateCustomerEmail
BEFORE INSERT ON Customer
FOR EACH ROW
BEGIN
    -- Check for basic email format validity
    IF NEW.Email NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid email format.';
    END IF;
END //
DELIMITER ;


-- 7.2. TRIGGER: BEFORE INSERT on Ticket (Business Rules & Integrity Checks)
-- Combines Date Check, Time Check, and Booking Limit Check
DELIMITER //
CREATE TRIGGER BeforeTicketInsert
BEFORE INSERT ON Ticket
FOR EACH ROW
BEGIN
    DECLARE event_date DATE;
    DECLARE event_time TIME;
    DECLARE ticket_count INT;
    DECLARE max_limit INT DEFAULT 5;
    
    SELECT Event_Date, Event_Time INTO event_date, event_time
    FROM Event
    WHERE Event_ID = NEW.Event_ID;
    
    -- Check 1: Prevent past bookings
    IF event_date < CURDATE() OR (event_date = CURDATE() AND event_time < CURTIME()) THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Cannot book tickets for an event that has already started or passed.';
    END IF;
    
    -- Check 2: Booking limit (Max 5 tickets per customer per event)
    SELECT COUNT(*) INTO ticket_count
    FROM Ticket
    WHERE Cust_ID = NEW.Cust_ID
      AND Event_ID = NEW.Event_ID
      AND Status = 'Booked';
      
    IF ticket_count >= max_limit THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Booking limit exceeded. Customer already holds the maximum number of tickets (5) for this event.';
    END IF;
    
    -- Note: Duplicate Seat Check is handled implicitly by the UNIQUE KEY(Event_ID, Seat_No) constraint.
END //
DELIMITER ;


-- 7.3. TRIGGER: AFTER INSERT on Ticket (Inventory and Logging)
-- (The original inventory update trigger, now includes logging)
DELIMITER //
CREATE TRIGGER AfterTicketInsert
AFTER INSERT ON Ticket
FOR EACH ROW
BEGIN
    -- 1. Inventory Management (Decrement available seats)
    UPDATE Seat_Category
    SET Available_Seats = Available_Seats - 1
    WHERE Category_ID = NEW.Category_ID;
    
    -- Optional: Update Status to 'Sold Out' if seats drop to zero
    IF (SELECT Available_Seats FROM Seat_Category WHERE Category_ID = NEW.Category_ID) = 0 THEN
        UPDATE Seat_Category
        SET Status = 'Sold Out'
        WHERE Category_ID = NEW.Category_ID;
    END IF;

    -- 2. Logging (Log customer activity)
    INSERT INTO Customer_Activity_Log (Cust_ID, Activity_Type, Details)
    VALUES (
        NEW.Cust_ID, 
        'Ticket Booked', 
        CONCAT('Booked Ticket #', NEW.Ticket_No, ' for Event #', NEW.Event_ID, ', Seat: ', NEW.Seat_No)
    );
END //
DELIMITER ;


-- 7.4. TRIGGER: AFTER UPDATE on Ticket (Cancellation Logic)
-- Restores seat and updates payment status on ticket cancellation
DELIMITER //
CREATE TRIGGER AfterTicketCancellation
AFTER UPDATE ON Ticket
FOR EACH ROW
BEGIN
    -- Only process if status changed from 'Booked' to 'Canceled'
    IF OLD.Status = 'Booked' AND NEW.Status = 'Canceled' THEN
        -- 1. Restore seat availability
        UPDATE Seat_Category
        SET Available_Seats = Available_Seats + 1,
            Status = 'Available'
        WHERE Category_ID = NEW.Category_ID;
        
        -- 2. Log the cancellation
        INSERT INTO Customer_Activity_Log (Cust_ID, Activity_Type, Details)
        VALUES (
            NEW.Cust_ID,
            'Ticket Canceled',
            CONCAT('Canceled Ticket #', NEW.Ticket_No, ' for Event #', NEW.Event_ID)
        );

        -- 3. Update related Payment status to 'Failed' (assuming no refund processing here)
        UPDATE Payment
        SET Payment_Status = 'Failed'
        WHERE Ticket_No = NEW.Ticket_No;
    END IF;
END //
DELIMITER ;


-- 7.5. TRIGGER: BEFORE DELETE on Event (Integrity)
DELIMITER //
CREATE TRIGGER PreventEventDeletion
BEFORE DELETE ON Event
FOR EACH ROW
BEGIN
    DECLARE ticket_count INT;
    
    SELECT COUNT(*) INTO ticket_count
    FROM Ticket
    WHERE Event_ID = OLD.Event_ID AND Status = 'Booked';
    
    IF ticket_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot delete event with active bookings. Cancel all tickets first.';
    END IF;
END //
DELIMITER ;


-- 7.6. TRIGGER: AFTER INSERT on Payment (Auto-Cancel on Failed Payment)
-- Note: This is now a simplified logic, as the BookTicket procedure assumes 'Successful' payment. 
-- In a real app, you would manually insert 'Failed' payments from a payment gateway hook.
DELIMITER //
CREATE TRIGGER UpdateTicketOnFailedPayment
AFTER INSERT ON Payment
FOR EACH ROW
BEGIN
    -- If a payment is logged as failed, the associated ticket should be canceled.
    IF NEW.Payment_Status = 'Failed' THEN
        -- This UPDATE will fire the AfterTicketCancellation trigger (7.4)
        UPDATE Ticket
        SET Status = 'Canceled'
        WHERE Ticket_No = NEW.Ticket_No;
    END IF;
END //
DELIMITER ;


--
-- 8. DEMO/TESTING
--

-- Initial Booking (Fires BeforeTicketInsert, AfterTicketInsert)
CALL BookTicket(
    1,                  -- Cust_ID: Alice Johnson
    1,                  -- Event_ID: The Rockers Concert
    'VIP',              -- Category_Name
    'A10',              -- Seat_No
    'Credit Card'       -- Mode_of_Payment
);
-- Second Booking (Bob)
CALL BookTicket(2, 1, 'General', 'B20', 'Cash');

-- Test 1: Full Booking Limit (Alice attempts 5 more bookings for Event 1)
CALL BookTicket(1, 1, 'General', 'C14', 'Credit Card'); -- Booking 3
CALL BookTicket(1, 1, 'General', 'C15', 'Credit Card'); -- Booking 4
CALL BookTicket(1, 1, 'General', 'C16', 'Credit Card'); -- Booking 5
CALL BookTicket(1, 1, 'General', 'C17', 'Credit Card'); -- Booking 6

-- This next call SHOULD FAIL due to the BEFORE INSERT TRIGGER (Limit 5):
SELECT '--- Attempting 7th ticket (SHOULD FAIL) ---';
-- If you run this in a client, it will throw Error 45000: 'Booking limit exceeded...'
-- CALL BookTicket(1, 1, 'General', 'C18', 'Credit Card'); 


-- Test 2: Ticket Cancellation (Fires AfterTicketCancellation)
SELECT '--- Canceling Ticket #1 (Alice) ---';
UPDATE Ticket 
SET Status = 'Canceled' 
WHERE Ticket_No = 1;


--
-- 9. COMPLEX QUERIES (Correlated, Nested, Window Functions)
--

-- Nested Query Example: Find the names of all events in the 'Grand Arena'
SELECT Event_ID, Event_Type
FROM Event
WHERE Venue_ID IN (
    SELECT Venue_ID
    FROM Venue
    WHERE Venue_Name = 'Grand Arena'
);

-- Correlated Subquery Example: Find customers who have paid more than the average final price for the event they booked.
SELECT 
    C.Cust_Name, 
    T.Final_Price, 
    E.Event_Type
FROM Customer C
JOIN Ticket T ON C.Cust_ID = T.Cust_ID
JOIN Event E ON T.Event_ID = E.Event_ID
WHERE T.Final_Price > (
    SELECT AVG(Final_Price)
    FROM Ticket T2
    WHERE T2.Event_ID = T.Event_ID -- Correlation condition
);

-- Window Function Example: Rank customers by their total spending.
WITH CustomerTotalSpent AS (
    SELECT 
        Cust_ID, 
        SUM(Final_Price) AS Total_Spent
    FROM Ticket
    WHERE Status = 'Booked' -- Only count active bookings
    GROUP BY Cust_ID
)
SELECT
    C.Cust_Name,
    CTS.Total_Spent,
    RANK() OVER (ORDER BY CTS.Total_Spent DESC) AS Spending_Rank
FROM Customer C
JOIN CustomerTotalSpent CTS ON C.Cust_ID = CTS.Cust_ID
ORDER BY Spending_Rank;

-- Example 3: View customer activity log
SELECT * FROM Customer_Activity_Log ORDER BY Log_ID DESC;