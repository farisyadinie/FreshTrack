import sqlite3

# Connect to database
connection = sqlite3.connect("database/freshtrack.db")

# Create cursor
cursor = connection.cursor()


# =========================
# USERS TABLE
# =========================

cursor.execute("""
CREATE TABLE IF NOT EXISTS users (

    id INTEGER PRIMARY KEY AUTOINCREMENT,

    name TEXT NOT NULL,

    email TEXT UNIQUE NOT NULL,

    password TEXT NOT NULL

)
""")


# =========================
# FOODS TABLE
# =========================

cursor.execute("""
CREATE TABLE IF NOT EXISTS foods (

    id INTEGER PRIMARY KEY AUTOINCREMENT,

    user_id INTEGER NOT NULL,

    food TEXT NOT NULL,

    category TEXT NOT NULL,

    quantity INTEGER NOT NULL,

    unit TEXT NOT NULL,

    expiry TEXT NOT NULL,

    status TEXT NOT NULL DEFAULT 'active',

    FOREIGN KEY (user_id) REFERENCES users(id)

)
""")


# Save changes
connection.commit()

print("FreshTrack database created successfully!")

# Close connection
connection.close()