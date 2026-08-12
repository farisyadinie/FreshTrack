import os
import sqlite3
from datetime import date, timedelta

from flask import Flask, render_template, request, session, redirect, jsonify
from flask_cors import CORS


app = Flask(__name__)

app.secret_key = "freshtrack-secret-key"

CORS(
    app,
    supports_credentials=True
)

# =====================================================
# LOCAL FLUTTER USER
# =====================================================

# For this local development project.
# This prevents Flutter Web from depending only
# on the browser session cookie.
api_user_id = None

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATABASE_DIR = os.path.join(BASE_DIR, "database")

os.makedirs(DATABASE_DIR, exist_ok=True)

DATABASE_PATH = os.path.join(DATABASE_DIR, "freshtrack.db")




# =====================================================
# DATABASE
# =====================================================

def db():
    return sqlite3.connect(DATABASE_PATH, timeout=10)


def ensure_food_impact_column():
    connection = db()
    cursor = connection.cursor()

    cursor.execute("PRAGMA table_info(foods)")
    columns = {
        row[1]
        for row in cursor.fetchall()
    }

    if "used_before_expiry" not in columns:
        cursor.execute("""
            ALTER TABLE foods
            ADD COLUMN used_before_expiry INTEGER DEFAULT 0
        """)

        # Preserve existing "used" records when upgrading.
        cursor.execute("""
            UPDATE foods
            SET used_before_expiry = 1
            WHERE status = 'used'
              AND (used_before_expiry IS NULL
                   OR used_before_expiry = 0)
        """)

    connection.commit()
    connection.close()


ensure_food_impact_column()


# =====================================================
# HOME
# =====================================================

@app.route("/")
def home():
    return render_template("index.html")


# =====================================================
# LOGIN - WEB
# =====================================================

@app.route("/login", methods=["GET", "POST"])
def login():

    if request.method == "POST":

        email = request.form["email"]
        password = request.form["password"]

        connection = db()
        cursor = connection.cursor()

        cursor.execute("""
            SELECT *
            FROM users
            WHERE email = ?
            AND password = ?
        """, (email, password))

        user = cursor.fetchone()

        connection.close()

        if user:

            session["user_id"] = user[0]

            return redirect("/dashboard")

        return render_template(
            "login.html",
            error="Invalid email or password"
        )

    return render_template("login.html")


# =====================================================
# REGISTER
# =====================================================

@app.route("/register", methods=["GET", "POST"])
def register():

    if request.method == "POST":

        name = request.form["name"]
        email = request.form["email"]
        password = request.form["password"]

        connection = db()
        cursor = connection.cursor()

        cursor.execute("""
            INSERT INTO users
            (
                name,
                email,
                password
            )
            VALUES (?, ?, ?)
        """, (
            name,
            email,
            password
        ))

        connection.commit()

        user_id = cursor.lastrowid

        connection.close()

        session["user_id"] = user_id

        return redirect("/dashboard")

    return render_template("register.html")


# =====================================================
# DASHBOARD - WEB
# =====================================================

@app.route("/dashboard")
def dashboard():

    if "user_id" not in session:
        return redirect("/login")

    user_id = session["user_id"]

    today = date.today()

    today_string = today.isoformat()

    three_days_string = (
        today + timedelta(days=3)
    ).isoformat()

    connection = db()
    cursor = connection.cursor()

    # USER

    cursor.execute("""
        SELECT name
        FROM users
        WHERE id = ?
    """, (user_id,))

    user = cursor.fetchone()

    if not user:

        connection.close()

        session.clear()

        return redirect("/login")


    # TOTAL FOODS

    cursor.execute("""
        SELECT COUNT(*)
        FROM foods
        WHERE user_id = ?
        AND status = 'active'
    """, (user_id,))

    total_foods = cursor.fetchone()[0]


    # EXPIRING SOON

    cursor.execute("""
        SELECT COUNT(*)
        FROM foods
        WHERE user_id = ?
        AND status = 'active'
        AND expiry BETWEEN ? AND ?
    """, (
        user_id,
        today_string,
        three_days_string
    ))

    expiring_soon = cursor.fetchone()[0]


    # EXPIRED

    cursor.execute("""
        SELECT COUNT(*)
        FROM foods
        WHERE user_id = ?
        AND status = 'active'
        AND expiry < ?
    """, (
        user_id,
        today_string
    ))

    expired = cursor.fetchone()[0]


    # LOW STOCK

    cursor.execute("""
        SELECT COUNT(*)
        FROM foods
        WHERE user_id = ?
        AND status = 'active'
        AND quantity <= 2
        AND expiry > ?
    """, (
        user_id,
        three_days_string
    ))

    low_stock = cursor.fetchone()[0]


    # PANTRY

    cursor.execute("""
        SELECT food, category, quantity, unit, expiry
        FROM foods
        WHERE user_id = ?
        AND status = 'active'
        ORDER BY expiry ASC
    """, (user_id,))

    raw_pantry_foods = cursor.fetchall()

    pantry_foods = []

    for row in raw_pantry_foods:

        food_name = row[0]
        category = row[1]
        quantity = float(row[2])
        unit = row[3]
        expiry = row[4]

        expiry_date = date.fromisoformat(expiry)

        days_until_expiry = (
            expiry_date - today
        ).days

        if days_until_expiry < 0:

            status_label = "Expired"
            status_class = "expired"

        elif days_until_expiry <= 3:

            status_label = "Expiring Soon"
            status_class = "expiring"

        elif quantity <= 2:

            status_label = "Low Stock"
            status_class = "low-stock"

        else:

            status_label = "Good"
            status_class = "good"


        if days_until_expiry < 0:

            days_ago = abs(days_until_expiry)

            if days_ago == 1:

                expiry_message = "Expired yesterday"

            else:

                expiry_message = (
                    f"Expired {days_ago} days ago"
                )

        elif days_until_expiry == 0:

            expiry_message = "Expires today"

        elif days_until_expiry == 1:

            expiry_message = "Expires tomorrow"

        else:

            expiry_message = (
                f"Expires in {days_until_expiry} days"
            )


        pantry_foods.append({
            "name": food_name,
            "category": category,
            "quantity": quantity,
            "unit": unit,
            "expiry": expiry,
            "status_label": status_label,
            "status_class": status_class,
            "expiry_message": expiry_message
        })


    # EXPIRING FOOD

    cursor.execute("""
        SELECT food, category, quantity, unit, expiry
        FROM foods
        WHERE user_id = ?
        AND status = 'active'
        AND expiry BETWEEN ? AND ?
        ORDER BY expiry ASC
    """, (
        user_id,
        today_string,
        three_days_string
    ))

    expiring_foods = cursor.fetchall()


    # LOW STOCK FOOD

    cursor.execute("""
        SELECT food, category, quantity, unit
        FROM foods
        WHERE user_id = ?
        AND status = 'active'
        AND quantity <= 2
        AND expiry > ?
        ORDER BY quantity ASC
    """, (
        user_id,
        three_days_string
    ))

    low_stock_foods = cursor.fetchall()


    # CATEGORY BREAKDOWN

    cursor.execute("""
        SELECT category, COUNT(*)
        FROM foods
        WHERE user_id = ?
        AND status = 'active'
        GROUP BY category
        ORDER BY COUNT(*) DESC
    """, (user_id,))

    category_breakdown = cursor.fetchall()


    # USED FOODS

    cursor.execute("""
        SELECT COALESCE(
            SUM(
                CASE
                    WHEN used_before_expiry = 1
                    THEN 1
                    ELSE 0
                END
            ),
            0
        )
        FROM foods
        WHERE user_id = ?
    """, (user_id,))

    used_foods = cursor.fetchone()[0]


    # IMPACT

    tracked_foods = used_foods + expired

    if tracked_foods > 0:

        waste_avoidance = round(
            (used_foods / tracked_foods) * 100
        )

    else:

        waste_avoidance = None


    # HEALTH

    health_score = (
        100
        - (expired * 10)
        - (expiring_soon * 5)
        - (low_stock * 2)
    )

    health_score = max(
        0,
        min(100, health_score)
    )


    if health_score >= 80:

        health_message = (
            "🌿 Great job! Your pantry is looking healthy."
        )

    elif health_score >= 50:

        health_message = (
            "🟡 Your pantry needs a little attention."
        )

    else:

        health_message = (
            "🔴 Your pantry needs attention."
        )


    connection.close()


    return render_template(
        "dashboard.html",
        name=user[0],
        total_foods=total_foods,
        expiring_soon=expiring_soon,
        expired=expired,
        low_stock=low_stock,
        pantry_foods=pantry_foods,
        expiring_foods=expiring_foods,
        low_stock_foods=low_stock_foods,
        category_breakdown=category_breakdown,
        used_foods=used_foods,
        waste_avoidance=waste_avoidance,
        health_score=health_score,
        health_message=health_message
    )


# =====================================================
# INVENTORY
# =====================================================

@app.route("/inventory", methods=["GET", "POST"])
def inventory():

    if "user_id" not in session:
        return redirect("/login")

    user_id = session["user_id"]

    today = date.today()

    today_string = today.isoformat()

    expiring_limit_date = (
        today + timedelta(days=3)
    ).isoformat()

    connection = db()
    cursor = connection.cursor()


    if request.method == "POST":

        food = request.form["food"]
        category = request.form["category"]

        try:

            quantity = float(
                request.form["quantity"]
            )

        except (ValueError, TypeError):

            connection.close()

            return "Invalid quantity", 400


        if quantity <= 0:

            connection.close()

            return "Quantity must be greater than 0", 400


        unit = request.form["unit"]
        expiry = request.form["expiry"]


        cursor.execute("""
            INSERT INTO foods
            (
                user_id,
                food,
                category,
                quantity,
                unit,
                expiry,
                status
            )
            VALUES (?, ?, ?, ?, ?, ?, 'active')
        """, (
            user_id,
            food,
            category,
            quantity,
            unit,
            expiry
        ))

        connection.commit()

        connection.close()

        return redirect("/inventory")


    filter_type = request.args.get(
        "filter",
        "all"
    )


    if filter_type == "expiring":

        cursor.execute("""
            SELECT *
            FROM foods
            WHERE user_id = ?
            AND status = 'active'
            AND expiry BETWEEN ? AND ?
            ORDER BY expiry ASC
        """, (
            user_id,
            today_string,
            expiring_limit_date
        ))

        filter_title = "⏰ Expiring Soon"


    elif filter_type == "expired":

        cursor.execute("""
            SELECT *
            FROM foods
            WHERE user_id = ?
            AND status = 'active'
            AND expiry < ?
            ORDER BY expiry ASC
        """, (
            user_id,
            today_string
        ))

        filter_title = "🔴 Expired Foods"


    elif filter_type == "low-stock":

        cursor.execute("""
            SELECT *
            FROM foods
            WHERE user_id = ?
            AND status = 'active'
            AND quantity <= 2
            AND expiry > ?
            ORDER BY quantity ASC
        """, (
            user_id,
            expiring_limit_date
        ))

        filter_title = "🟡 Low Stock"


    else:

        cursor.execute("""
            SELECT *
            FROM foods
            WHERE user_id = ?
            AND status = 'active'
            ORDER BY expiry ASC
        """, (user_id,))

        filter_title = "🥕 Your Pantry"


    foods = cursor.fetchall()

    connection.close()


    return render_template(
        "inventory.html",
        foods=foods,
        today=today_string,
        expiring_limit=expiring_limit_date,
        filter_title=filter_title,
        filter_type=filter_type
    )


# =====================================================
# EDIT
# =====================================================

@app.route("/edit/<int:id>", methods=["GET", "POST"])
def edit(id):

    if "user_id" not in session:
        return redirect("/login")

    user_id = session["user_id"]

    connection = db()
    cursor = connection.cursor()


    if request.method == "POST":

        food = request.form["food"]
        category = request.form["category"]

        try:

            quantity = float(
                request.form["quantity"]
            )

        except (ValueError, TypeError):

            connection.close()

            return "Invalid quantity", 400


        if quantity <= 0:

            connection.close()

            return "Quantity must be greater than 0", 400


        unit = request.form["unit"]
        expiry = request.form["expiry"]


        cursor.execute("""
            UPDATE foods
            SET food = ?,
                category = ?,
                quantity = ?,
                unit = ?,
                expiry = ?
            WHERE id = ?
            AND user_id = ?
        """, (
            food,
            category,
            quantity,
            unit,
            expiry,
            id,
            user_id
        ))

        connection.commit()

        connection.close()

        return redirect("/inventory")


    cursor.execute("""
        SELECT *
        FROM foods
        WHERE id = ?
        AND user_id = ?
        AND status = 'active'
    """, (
        id,
        user_id
    ))

    food = cursor.fetchone()

    connection.close()


    return render_template(
        "edit.html",
        food=food
    )


# =====================================================
# USED
# =====================================================

@app.route("/used/<int:id>")
def used(id):

    if "user_id" not in session:
        return redirect("/login")

    user_id = session["user_id"]

    connection = db()
    cursor = connection.cursor()

    cursor.execute("""
        UPDATE foods
        SET status = 'used'
        WHERE id = ?
        AND user_id = ?
    """, (
        id,
        user_id
    ))

    connection.commit()

    connection.close()

    return redirect("/inventory")


# =====================================================
# DELETE
# =====================================================

@app.route("/delete/<int:id>")
def delete(id):

    if "user_id" not in session:
        return redirect("/login")

    user_id = session["user_id"]

    connection = db()
    cursor = connection.cursor()

    cursor.execute("""
        DELETE FROM foods
        WHERE id = ?
        AND user_id = ?
    """, (
        id,
        user_id
    ))

    connection.commit()

    connection.close()

    return redirect("/inventory")


# =====================================================
# FLUTTER LOGIN API
# =====================================================

@app.route("/api/login", methods=["POST"])
def api_login():

    global api_user_id

    data = request.get_json(silent=True) or {}

    email = data.get("email")
    password = data.get("password")

    if not email or not password:

        return jsonify({
            "error": "Email and password are required"
        }), 400


    connection = db()
    cursor = connection.cursor()

    cursor.execute("""
        SELECT id, name, email
        FROM users
        WHERE email = ?
        AND password = ?
    """, (
        email,
        password
    ))

    user = cursor.fetchone()

    connection.close()


    if not user:

        return jsonify({
            "error": "Invalid email or password"
        }), 401


    # SAVE USER FOR FLUTTER API

    api_user_id = user[0]

    # ALSO SAVE NORMAL FLASK SESSION

    session["user_id"] = user[0]


    return jsonify({
        "success": True,
        "id": user[0],
        "name": user[1],
        "email": user[2]
    }), 200


# =====================================================
# FLUTTER DASHBOARD API
# =====================================================

@app.route("/api/dashboard")
def api_dashboard():

    global api_user_id

    user_id = session.get("user_id") or api_user_id

    if user_id is None:

        return jsonify({
            "error": "Not logged in"
        }), 401


    today = date.today()

    today_string = today.isoformat()

    three_days_string = (
        today + timedelta(days=3)
    ).isoformat()


    connection = db()
    cursor = connection.cursor()


    cursor.execute("""
        SELECT name
        FROM users
        WHERE id = ?
    """, (user_id,))

    user = cursor.fetchone()


    if not user:

        connection.close()

        return jsonify({
            "error": "User not found"
        }), 401


    # TOTAL FOODS

    cursor.execute("""
        SELECT COUNT(*)
        FROM foods
        WHERE user_id = ?
        AND status = 'active'
    """, (user_id,))

    total_foods = cursor.fetchone()[0]


    # EXPIRING

    cursor.execute("""
        SELECT COUNT(*)
        FROM foods
        WHERE user_id = ?
        AND status = 'active'
        AND expiry BETWEEN ? AND ?
    """, (
        user_id,
        today_string,
        three_days_string
    ))

    expiring_soon = cursor.fetchone()[0]


    # EXPIRED

    cursor.execute("""
        SELECT COUNT(*)
        FROM foods
        WHERE user_id = ?
        AND status = 'active'
        AND expiry < ?
    """, (
        user_id,
        today_string
    ))

    expired = cursor.fetchone()[0]


    # LOW STOCK

    cursor.execute("""
        SELECT COUNT(*)
        FROM foods
        WHERE user_id = ?
        AND status = 'active'
        AND quantity <= 2
        AND expiry > ?
    """, (
        user_id,
        three_days_string
    ))

    low_stock = cursor.fetchone()[0]


    # USED

    cursor.execute("""
        SELECT COUNT(*)
        FROM foods
        WHERE user_id = ?
        AND status = 'used'
    """, (user_id,))

    used_foods = cursor.fetchone()[0]


    tracked_foods = used_foods + expired


    if tracked_foods > 0:

        waste_avoidance = round(
            (used_foods / tracked_foods) * 100
        )

    else:

        waste_avoidance = 0


    connection.close()


    return jsonify({
        "name": user[0],
        "total_foods": total_foods,
        "expiring_soon": expiring_soon,
        "expired": expired,
        "low_stock": low_stock,
        "used_foods": used_foods,
        "waste_avoidance": waste_avoidance
    })


# =====================================================
# FLUTTER GET FOODS
# =====================================================

@app.route("/api/foods", methods=["GET"])
def api_foods():

    global api_user_id

    user_id = session.get("user_id") or api_user_id

    if user_id is None:

        return jsonify({
            "error": "Not logged in"
        }), 401


    connection = db()
    cursor = connection.cursor()

    cursor.execute("""
        SELECT id, food, category, quantity, unit, expiry
        FROM foods
        WHERE user_id = ?
        AND status = 'active'
        ORDER BY expiry ASC
    """, (user_id,))

    rows = cursor.fetchall()

    connection.close()


    foods = []

    for row in rows:

        foods.append({
            "id": row[0],
            "food": row[1],
            "category": row[2],
            "quantity": row[3],
            "unit": row[4],
            "expiry": row[5]
        })


    return jsonify({
        "foods": foods
    })


# =====================================================
# FLUTTER ADD FOOD
# =====================================================

@app.route("/api/foods", methods=["POST"])
def api_add_food():

    global api_user_id

    user_id = session.get("user_id") or api_user_id

    if user_id is None:

        return jsonify({
            "error": "Not logged in"
        }), 401


    data = request.get_json(silent=True) or {}

    food = data.get("food")
    category = data.get("category")
    quantity = data.get("quantity")
    unit = data.get("unit")
    expiry = data.get("expiry")


    if (
        not food
        or not category
        or quantity is None
        or not unit
        or not expiry
    ):

        return jsonify({
            "error": "Missing required fields"
        }), 400


    try:

        quantity = float(quantity)

    except (ValueError, TypeError):

        return jsonify({
            "error": "Invalid quantity"
        }), 400


    if quantity <= 0:

        return jsonify({
            "error": "Quantity must be greater than 0"
        }), 400


    connection = db()
    cursor = connection.cursor()


    cursor.execute("""
        INSERT INTO foods
        (
            user_id,
            food,
            category,
            quantity,
            unit,
            expiry,
            status
        )
        VALUES (?, ?, ?, ?, ?, ?, 'active')
    """, (
        user_id,
        food,
        category,
        quantity,
        unit,
        expiry
    ))


    connection.commit()

    food_id = cursor.lastrowid

    connection.close()


    return jsonify({
        "success": True,
        "id": food_id
    }), 201


# =====================================================
# FLUTTER EDIT FOOD
# =====================================================

@app.route("/api/foods/<int:id>", methods=["PUT"])
def api_edit_food(id):

    global api_user_id

    user_id = session.get("user_id") or api_user_id

    if user_id is None:

        return jsonify({
            "error": "Not logged in"
        }), 401


    data = request.get_json(silent=True) or {}

    food = data.get("food")
    category = data.get("category")
    quantity = data.get("quantity")
    unit = data.get("unit")
    expiry = data.get("expiry")


    try:

        quantity = float(quantity)

    except (ValueError, TypeError):

        return jsonify({
            "error": "Invalid quantity"
        }), 400


    if quantity <= 0:

        return jsonify({
            "error": "Quantity must be greater than 0"
        }), 400


    connection = db()
    cursor = connection.cursor()


    cursor.execute("""
        UPDATE foods
        SET food = ?,
            category = ?,
            quantity = ?,
            unit = ?,
            expiry = ?
        WHERE id = ?
        AND user_id = ?
        AND status = 'active'
    """, (
        food,
        category,
        quantity,
        unit,
        expiry,
        id,
        user_id
    ))


    connection.commit()

    changed = cursor.rowcount

    connection.close()


    if changed == 0:

        return jsonify({
            "error": "Food not found"
        }), 404


    return jsonify({
        "success": True
    })


# =====================================================
# FLUTTER USED FOOD
# =====================================================

@app.route("/api/foods/<int:id>/use-one", methods=["POST"])
def api_use_one_food(id):

    global api_user_id

    user_id = session.get("user_id") or api_user_id

    if user_id is None:
        return jsonify({
            "error": "Not logged in"
        }), 401

    connection = db()
    cursor = connection.cursor()

    cursor.execute("""
        SELECT quantity, unit, food, status, expiry
        FROM foods
        WHERE id = ?
        AND user_id = ?
    """, (id, user_id))

    row = cursor.fetchone()

    if row is None:
        connection.close()
        return jsonify({
            "error": "Food not found"
        }), 404

    quantity, unit, food_name, status, expiry = row

    if status != "active":
        connection.close()
        return jsonify({
            "error": "This food is already used up."
        }), 400

    try:
        current_quantity = float(quantity)
    except (TypeError, ValueError):
        connection.close()
        return jsonify({
            "error": "Invalid food quantity."
        }), 400

    if current_quantity <= 0:
        connection.close()
        return jsonify({
            "error": "Food quantity is already zero."
        }), 400

    new_quantity = max(
        current_quantity - 1,
        0
    )

    if new_quantity <= 0:
        cursor.execute("""
            UPDATE foods
            SET quantity = 0,
                status = 'used',
                used_before_expiry = CASE
                    WHEN expiry >= ? THEN 1
                    ELSE 0
                END
            WHERE id = ?
            AND user_id = ?
            AND status = 'active'
        """, (
            date.today().isoformat(),
            id,
            user_id
        ))
    else:
        cursor.execute("""
            UPDATE foods
            SET quantity = ?
            WHERE id = ?
            AND user_id = ?
            AND status = 'active'
        """, (
            new_quantity,
            id,
            user_id
        ))

    connection.commit()
    connection.close()

    return jsonify({
        "success": True,
        "quantity": new_quantity,
        "unit": unit,
        "food": food_name,
        "used_up": new_quantity <= 0
    })


# =====================================================
# FLUTTER DELETE FOOD
# =====================================================

@app.route("/api/foods/<int:id>", methods=["DELETE"])
def api_delete_food(id):

    global api_user_id

    user_id = session.get("user_id") or api_user_id

    if user_id is None:

        return jsonify({
            "error": "Not logged in"
        }), 401


    connection = db()
    cursor = connection.cursor()


    cursor.execute("""
        DELETE FROM foods
        WHERE id = ?
        AND user_id = ?
    """, (
        id,
        user_id
    ))


    connection.commit()

    changed = cursor.rowcount

    connection.close()


    if changed == 0:

        return jsonify({
            "error": "Food not found"
        }), 404


    return jsonify({
        "success": True
    })


# =====================================================
# LOGOUT
# =====================================================

@app.route("/logout")
def logout():

    global api_user_id

    session.clear()

    api_user_id = None

    return redirect("/")


# =====================================================
# RUN
# =====================================================

if __name__ == "__main__":

    app.run(
        host="0.0.0.0",
        port=5000,
        debug=True
    )