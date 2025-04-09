# whoosh

Flutter app front end while Node.js-based API built with Express.js and Prisma ORM for managing various business operations. It includes features for user authentication, order management, journey planning, leave applications, product management, and reporting. Here's a high-level overview:

Key Features:
Authentication and Authorization:

User registration and login with JWT-based authentication.
Middleware for role-based access control (e.g., admin-only routes).
Order Management:

Create, update, retrieve, and delete orders.
Manage order items and validate product stock levels.
Journey Planning:

Create and update journey plans for users.
Includes features like check-in, checkout, and geolocation tracking.
Leave Management:

Submit leave applications with optional file attachments.
Admins can view and update the status of leave applications.
Product Management:

CRUD operations for products, including image uploads via ImageKit.
Manage stock levels, reorder points, and product details.
Reporting:

Generate and manage reports for feedback, product availability, and visibility activities.
Supports linking reports to orders, journey plans, and outlets.
Notice Board:

Retrieve notices for users.
Profile Management:

Update user profile photos and retrieve profile details.
File Uploads:

Upload and manage files (e.g., images, PDFs) using ImageKit.
Database:

Uses MySQL as the database, managed via Prisma ORM.
Includes models for users, orders, products, journey plans, reports, and more.
Deployment:

Configured for deployment on Vercel with a vercel.json file.
Tech Stack:
Backend: Node.js, Express.js
Database: MySQL (via Prisma ORM)
Authentication: JWT
File Storage: ImageKit
Environment Management: dotenv
Logging: Morgan
Deployment: Vercel
Folder Structure:
controllers: Contains business logic for various features.
routes: Defines API endpoints for features like authentication, orders, products, etc.
middleware: Middleware for authentication, authorization, and role checks.
prisma: Prisma schema and migrations for database management.
uploads: Directory for storing uploaded files.
scripts: Utility scripts (e.g., setting a user as admin).
