CREATE TABLE employee_master (
    emp_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    mid_name VARCHAR(50),
    last_name VARCHAR(50) NOT NULL,
    email_id VARCHAR(100) NOT NULL UNIQUE,
    phone_number VARCHAR(15) NOT NULL UNIQUE,
    date_of_birth DATE NOT NULL,
    gender ENUM('Male','Female','Other') NOT NULL,
    department_id INT NOT NULL,
    role_id INT NOT NULL,
    date_of_joining DATE NOT NULL,
    date_of_relieving DATE NULL,
    employment_type ENUM('Permanent','Contract','Intern') NOT NULL,
    work_type ENUM('Full Time','Part Time') NOT NULL,
    permanent_address TEXT NOT NULL,
    communication_address TEXT,
    aadhar_number CHAR(12) UNIQUE,
    pan_number CHAR(10) UNIQUE,
    passport_number VARCHAR(20) UNIQUE,
    status ENUM('Active','Inactive','Relieved') DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) AUTO_INCREMENT = 100;

select * from employee_master;


ALTER TABLE employee_master
ADD department_id INT NOT NULL,
ADD role_id INT NOT NULL;

ALTER TABLE employee_master
ADD CONSTRAINT fk_department
FOREIGN KEY (department_id)
REFERENCES department_master(department_id);

ALTER TABLE employee_master
ADD CONSTRAINT fk_role
FOREIGN KEY (role_id)
REFERENCES role_master(role_id);



describe employee_master;
INSERT INTO employee_master
(first_name, mid_name, last_name, email_id, phone_number,
 date_of_birth, gender, department_id, role_id,
 date_of_joining, date_of_relieving,
 employment_type, work_type,
 permanent_address, communication_address,
 aadhar_number, pan_number, passport_number,
 status, created_at, updated_at)
VALUES

('Rahul','K','Sharma','rahul.sharma@gmail.com','9876543210',
 '1990-01-15','Male',1,1,
 '2015-06-01',NULL,
 'Permanent','Full Time',
 'Delhi','Delhi',
 '123456789012','ABCDE1234F','P1234567',
 'Active',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP),

('Priya',NULL,'Singh','priya.singh@gmail.com','9876543211',
 '1995-04-20','Female',2,2,
 '2018-07-10',NULL,
 'Permanent','Full Time',
 'Mumbai','Mumbai',
 '234567890123','BCDEF2345G','P2345678',
 'Active',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP),

('Amit','R','Verma','amit.verma@gmail.com','9876543212',
 '1992-09-05','Male',3,3,
 '2016-03-15','2024-12-31',
 'Contract','Full Time',
 'Pune','Pune',
 '345678901234','CDEFG3456H','P3456789',
 'Relieved',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP),

('Neha','M','Patel','neha.patel@gmail.com','9876543213',
 '1998-11-25','Female',4,4,
 '2021-08-01',NULL,
 'Permanent','Part Time',
 'Ahmedabad','Ahmedabad',
 '456789012345','DEFGH4567J','P4567890',
 'Active',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP),

('Suresh',NULL,'Kumar','suresh.kumar@gmail.com','9876543214',
 '1988-02-10','Male',5,5,
 '2012-01-05','2023-05-30',
 'Permanent','Full Time',
 'Chennai','Chennai',
 '567890123456','EFGHI5678K','P5678901',
 'Relieved',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP);

 
CREATE TABLE department_master (
    department_id INT AUTO_INCREMENT PRIMARY KEY,
    department_name VARCHAR(50) NOT NULL UNIQUE
);


CREATE TABLE role_master (
    role_id INT AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE
);

ALTER TABLE department_master
ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE role_master
ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

INSERT INTO department_master (department_name)
VALUES ('IT'),('HR'),('Finance'),('Sales'),('Admin');

INSERT INTO role_master (role_name)
VALUES ('Developer'),('HR Executive'),('Accountant'),
       ('Sales Executive'),('Office Admin'),('Intern');

select * from department_master;

-- triger creation 
DELIMITER $$

CREATE TRIGGER trg_require_relieving_date
BEFORE UPDATE ON employee_master
FOR EACH ROW
BEGIN
    IF NEW.status = 'Relieved' AND NEW.date_of_relieving IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Relieving date must be provided when status is Relieved';
    END IF;
END$$

DELIMITER ;

-- sample datas
INSERT INTO employee_master
(first_name, mid_name, last_name, email_id, phone_number,
 date_of_birth, gender, department_id, role_id,
 date_of_joining, date_of_relieving,
 employment_type, work_type,
 permanent_address, communication_address,
 aadhar_number, pan_number, passport_number,
 status)
VALUES

('Rahul','K','Sharma','rahul.sharma@gmail.com','9876543210',
 '1990-01-15','Male',1,1,
 '2015-06-01',NULL,
 'Permanent','Full Time',
 'Delhi','Delhi',
 '123456789012','ABCDE1234F','P1234567',
 'Active'),

('Priya',NULL,'Singh','priya.singh@gmail.com','9876543211',
 '1995-04-20','Female',2,2,
 '2018-07-10',NULL,
 'Permanent','Full Time',
 'Mumbai','Mumbai',
 '234567890123','BCDEF2345G','P2345678',
 'Active'),

('Amit','R','Verma','amit.verma@gmail.com','9876543212',
 '1992-09-05','Male',3,3,
 '2016-03-15','2024-12-31',
 'Contract','Full Time',
 'Pune','Pune',
 '345678901234','CDEFG3456H','P3456789',
 'Relieved'),

('Neha','M','Patel','neha.patel@gmail.com','9876543213',
 '1998-11-25','Female',4,4,
 '2021-08-01',NULL,
 'Permanent','Part Time',
 'Ahmedabad','Ahmedabad',
 '456789012345','DEFGH4567J','P4567890',
 'Active'),

('Suresh',NULL,'Kumar','suresh.kumar@gmail.com','9876543214',
 '1988-02-10','Male',5,5,
 '2012-01-05','2023-05-30',
 'Permanent','Full Time',
 'Chennai','Chennai',
 '567890123456','EFGHI5678K','P5678901',
 'Relieved');

-- testing 
UPDATE employee_master
SET status = 'Relieved',date_of_relieving = '2025-12-31'
WHERE emp_id = 101;

select * from employee_master;


-- leave Master 
CREATE TABLE leave_master (
    leave_id INT AUTO_INCREMENT PRIMARY KEY,
    emp_id INT NOT NULL,
    
    leave_type ENUM('Casual','Sick','Paid','Maternity','Paternity','Other') NOT NULL,
    leave_start_date DATE NOT NULL,
    leave_end_date DATE NOT NULL,
    number_of_days INT GENERATED ALWAYS AS (DATEDIFF(leave_end_date, leave_start_date) + 1) STORED,
    approved_by ENUM('HR','Manager','Admin') DEFAULT NULL,
    
    status ENUM('Pending','Approved','Rejected') DEFAULT 'Pending',
    reason TEXT,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_leave_employee FOREIGN KEY (emp_id)
        REFERENCES employee_master(emp_id)
        ON DELETE CASCADE
);




INSERT INTO leave_master
(emp_id, leave_type, leave_start_date, leave_end_date, approved_by, status, reason)
VALUES
(100, 'Casual', '2026-02-10', '2026-02-12', 'HR', 'Approved', 'Personal work'),
(101, 'Sick', '2026-03-01', '2026-03-03', NULL, 'Pending', 'Fever and rest'),
(102, 'Paid', '2026-04-15', '2026-04-20', 'Manager', 'Approved', 'Vacation trip'),
(103, 'Maternity', '2026-05-01', '2026-07-31', 'HR', 'Approved', 'Childbirth leave'),
(104, 'Paternity', '2026-06-15', '2026-06-20', 'Admin', 'Approved', 'Childcare leave'),
(100, 'Other', '2026-07-10', '2026-07-12', NULL, 'Pending', 'House moving');

update leave_master set approved_by="Admin", status="Approved" where leave_id=6;

select * from leave_master;

show tables;


CREATE TABLE login_master (
    login_id INT AUTO_INCREMENT PRIMARY KEY,
    emp_id INT,
    username VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role ENUM('Employee','HR','Admin') NOT NULL,
    status ENUM('Active','Inactive') DEFAULT 'Active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_login_emp FOREIGN KEY (emp_id) REFERENCES employee_master(emp_id) ON DELETE CASCADE
);

truncate table login_master;

INSERT INTO login_master (emp_id, username, password, role) VALUES
(100, 'emp@test.com', '000000', 'Employee'),
(102, 'admin@test.com', '111111', 'Admin'),
(103, 'hr@test.com', '222222', 'HR'),
(104, 'em@test.com', '222000', 'Employee');

select * from login_master;

select * from employee_master;