import tkinter as tk
from tkinter import messagebox, ttk
from PIL import Image, ImageTk
import pyodbc
import datetime
import os

conn = pyodbc.connect(
    'DRIVER={ODBC Driver 18 for SQL Server};'
    'SERVER=DESKTOP-V4R5J4Q\\SQLEXPRESS;'
    'DATABASE=MentalHealthTrackerDB;'
    'Trusted_Connection=yes;'
    r"TrustServerCertificate=yes;"
)
cursor = conn.cursor()

root = tk.Tk()
root.title("Mental Health Tracker")
root.geometry("800x600")
root.configure(bg="#ADD8E6")

current_user_id = None
current_username = None
frames = {}

for F in ("Welcome", "Signup", "Login", "Dashboard", "Questionnaire", "Lifestyle", "Result"):
    frame = tk.Frame(root, bg="#ADD8E6")
    frame.grid(row=0, column=0, sticky='nsew')
    frames[F] = frame

def show_frame(frame):
    frame.tkraise()

def get_mood_explanation_by_label(label):
    moods = {
        "Minimal or No Depression": ("You're doing well!", "😊", "lightgreen"),
        "Mild Depression": ("A little low, but manageable.", "🙂", "lightyellow"),
        "Moderate Depression": ("Consider talking to someone.", "😐", "orange"),
        "Moderately Severe Depression": ("Seek professional help.", "😟", "tomato"),
        "Severe Depression": ("It's important to reach out.", "😢", "red")
    }
    return moods.get(label, ("Mood level unknown.", "❓", "gray"))

# === Welcome Page ===
def setup_welcome():
    frame = frames["Welcome"]
    for w in frame.winfo_children():
        w.destroy()
    frame.configure(bg="#ADD8E6")

    container = tk.Frame(frame, bg="#ADD8E6")
    container.pack(expand=True, fill="both", padx=50, pady=50)

    left_frame = tk.Frame(container, bg="#ADD8E6")
    left_frame.pack(side="left", fill="both", expand=False)

    image_path = r"C:\Users\Dell\Python\welcome_poster.png"
    if os.path.exists(image_path):
        img = Image.open(image_path).resize((350, 500), Image.Resampling.LANCZOS)
        photo = ImageTk.PhotoImage(img)
        img_label = tk.Label(left_frame, image=photo, bg="#ADD8E6")
        img_label.image = photo
        img_label.pack(expand=True, fill="both")
    else:
        tk.Label(left_frame, text="Image not found", bg="#ADD8E6", fg="red").pack()

    right_frame = tk.Frame(container, bg="#ADD8E6")
    right_frame.pack(side="left", fill="both", expand=True, padx=40)

    tk.Label(
        right_frame,
        text="Welcome to Mental Health Tracker",
        font=("Helvetica", 26, "bold"),
        bg="#ADD8E6",
        wraplength=350,
        justify="center"
    ).pack(pady=100)

    tk.Button(right_frame, text="Login", width=20, font=("Helvetica", 14),
              command=lambda: show_frame(frames["Login"])).pack(pady=15)
    tk.Button(right_frame, text="Signup", width=20, font=("Helvetica", 14),
              command=lambda: show_frame(frames["Signup"])).pack(pady=15)

# === Signup/Login ===
def signup_user():
    username = username_entry.get().strip()
    password = password_entry.get().strip()
    if not username or not password:
        messagebox.showerror("Input Error", "Username and Password cannot be empty.")
        return
    try:
        cursor.execute("EXEC dbo.MHT_SignupUser ?, ?", username, password)
        conn.commit()
        messagebox.showinfo("Success", "Signup successful! Please login.")
        show_frame(frames["Login"])
    except Exception as e:
        messagebox.showerror("Error", str(e))

def setup_signup():
    frame = frames["Signup"]
    for w in frame.winfo_children():
        w.destroy()
    global username_entry, password_entry
    tk.Label(frame, text="Signup", font=("Helvetica", 18), bg="#ADD8E6").pack(pady=20)
    tk.Label(frame, text="Username", bg="#ADD8E6").pack()
    username_entry = tk.Entry(frame)
    username_entry.pack()
    tk.Label(frame, text="Password", bg="#ADD8E6").pack()
    password_entry = tk.Entry(frame, show="*")
    password_entry.pack()
    tk.Button(frame, text="Signup", command=signup_user).pack(pady=10)
    tk.Button(frame, text="Back", command=lambda: show_frame(frames["Welcome"])).pack()

def login_user():
    global current_user_id, current_username
    username = login_username.get().strip()
    password = login_password.get().strip()
    if not username or not password:
        messagebox.showerror("Input Error", "Please enter both username and password.")
        return
    try:
        cursor.execute("EXEC dbo.MHT_LoginUser ?, ?", username, password)
        result = cursor.fetchone()
        if result and result[0]:
            current_user_id = result[0]
            current_username = username
            messagebox.showinfo("Success", result[1])
            setup_dashboard()
            show_frame(frames["Dashboard"])
        else:
            messagebox.showerror("Login Failed", "Invalid username or password")
    except Exception as e:
        messagebox.showerror("Error", str(e))

def setup_login():
    frame = frames["Login"]
    for w in frame.winfo_children():
        w.destroy()
    global login_username, login_password
    tk.Label(frame, text="Login", font=("Helvetica", 18), bg="#ADD8E6").pack(pady=20)
    tk.Label(frame, text="Username", bg="#ADD8E6").pack()
    login_username = tk.Entry(frame)
    login_username.pack()
    tk.Label(frame, text="Password", bg="#ADD8E6").pack()
    login_password = tk.Entry(frame, show="*")
    login_password.pack()
    tk.Button(frame, text="Login", command=login_user).pack(pady=10)
    tk.Button(frame, text="Back", command=lambda: show_frame(frames["Welcome"])).pack()

# === Dashboard ===
def setup_dashboard():
    frame = frames["Dashboard"]
    for w in frame.winfo_children():
        w.destroy()
    welcome_msg = f"Hello, {current_username}! Welcome to the Dashboard."
    tk.Label(frame, text=welcome_msg, font=("Helvetica", 16), bg="#ADD8E6").pack(pady=20)

    def go_questionnaire():
        setup_questionnaire()
        show_frame(frames["Questionnaire"])

    def go_lifestyle():
        setup_lifestyle()
        show_frame(frames["Lifestyle"])

    tk.Button(frame, text="Take Questionnaire", width=30, command=go_questionnaire).pack(pady=10)
    tk.Button(frame, text="Log Lifestyle", width=30, command=go_lifestyle).pack(pady=10)
    tk.Button(frame, text="Predict Mood", width=30, command=predict_mood).pack(pady=10)
    tk.Button(frame, text="Logout", width=30, command=lambda: show_frame(frames["Welcome"])).pack(pady=30)

# === Questionnaire ===
answers = {}
options_text = [
    "Not at all (0)", "Several days (1)", "More than half the days (2)", "Nearly every day (3)"
]

def submit_questionnaire():
    today = datetime.date.today()
    try:
        for qid, score_var in answers.items():
            selected_text = score_var.get()
            score = int(selected_text.split("(")[-1].split(")")[0])
            cursor.execute("EXEC dbo.MHT_InsertUserAnswer ?, ?, ?, ?", current_user_id, qid, today, score)
        conn.commit()
        messagebox.showinfo("Submitted", "Answers recorded.")
        show_frame(frames["Dashboard"])
    except Exception as e:
        messagebox.showerror("Error", str(e))

def setup_questionnaire():
    frame = frames["Questionnaire"]
    for w in frame.winfo_children():
        w.destroy()

    tk.Label(frame, text="PHQ-9 Questionnaire", font=("Helvetica", 18), bg="#ADD8E6").pack(pady=10)


    canvas = tk.Canvas(frame, bg="#ADD8E6", highlightthickness=0)
    scrollbar = ttk.Scrollbar(frame, orient="vertical", command=canvas.yview)
    scrollable_frame = tk.Frame(canvas, bg="#ADD8E6")

    scrollable_frame.bind(
        "<Configure>",
        lambda e: canvas.configure(
            scrollregion=canvas.bbox("all")
        )
    )

    canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
    canvas.configure(yscrollcommand=scrollbar.set)

    canvas.pack(side="left", fill="both", expand=True, padx=(20,0))
    scrollbar.pack(side="right", fill="y")

    global answers
    answers = {}
    cursor.execute("SELECT question_id, question_text FROM dbo.MHT_QuestionsList")
    questions = cursor.fetchall()

    for qid, qtext in questions:
        tk.Label(scrollable_frame, text=qtext, bg="#ADD8E6").pack(anchor="w", pady=2)
        score_var = tk.StringVar(value=options_text[0])
        answers[qid] = score_var
        score_box = ttk.Combobox(scrollable_frame, textvariable=score_var, values=options_text, state="readonly")
        score_box.pack(anchor="w")

    btn_frame = tk.Frame(frame, bg="#ADD8E6")
    btn_frame.pack(pady=10)
    tk.Button(btn_frame, text="Submit", command=submit_questionnaire).pack(side="left", padx=10)
    tk.Button(btn_frame, text="Back", command=lambda: show_frame(frames["Dashboard"])).pack(side="left", padx=10)

# === Lifestyle ===
def submit_lifestyle():
    today = datetime.date.today()
    try:
        sleep = float(sleep_entry.get())
        exercise = int(exercise_entry.get())
        if sleep < 0 or sleep > 24 or exercise < 0:
            raise ValueError("Invalid values")
        cursor.execute("EXEC dbo.MHT_InsertLifestyleRecord ?, ?, ?, ?", current_user_id, today, sleep, exercise)
        conn.commit()
        messagebox.showinfo("Saved", "Lifestyle data saved.")
        show_frame(frames["Dashboard"])
    except Exception as e:
        messagebox.showerror("Error", str(e))

def setup_lifestyle():
    frame = frames["Lifestyle"]
    for w in frame.winfo_children():
        w.destroy()
    global sleep_entry, exercise_entry
    tk.Label(frame, text="Lifestyle Entry", font=("Helvetica", 18), bg="#ADD8E6").pack(pady=10)
    tk.Label(frame, text="Hours of Sleep (0-24)", bg="#ADD8E6").pack()
    sleep_entry = tk.Entry(frame)
    sleep_entry.pack()
    tk.Label(frame, text="Minutes of Exercise ", bg="#ADD8E6").pack()
    exercise_entry = tk.Entry(frame)
    exercise_entry.pack()
    tk.Button(frame, text="Submit", command=submit_lifestyle).pack(pady=20)
    tk.Button(frame, text="Back", command=lambda: show_frame(frames["Dashboard"])).pack()

# === Result ===
def predict_mood():
    today = datetime.date.today()
    try:
        cursor.execute("EXEC dbo.MHT_PredictMood ?, ?", current_user_id, today)
        result = cursor.fetchone()
        if result:
            mood_label = result[0]
            mood_score = result[1]  # Assuming second value is the score
            explanation, emoji, color = get_mood_explanation_by_label(mood_label)
            setup_result(mood_label, mood_score, explanation, emoji, color)
            show_frame(frames["Result"])
        else:
            messagebox.showinfo("No Data", "No questionnaire data found for today.")
    except Exception as e:
        messagebox.showerror("Error", str(e))
def setup_result(label, score, explanation, emoji, color):
    frame = frames["Result"]
    for w in frame.winfo_children():
        w.destroy()
    frame.configure(bg=color)

    # Mood result display
    tk.Label(frame, text="Mood Prediction Result", font=("Helvetica", 18, "bold"), bg=color).pack(pady=20)
    tk.Label(frame, text=f"Mood Level: {label}", font=("Helvetica", 14), bg=color).pack(pady=5)
    tk.Label(frame, text=f"Score: {score}", font=("Helvetica", 14), bg=color).pack(pady=5)
    tk.Label(frame, text=emoji, font=("Helvetica", 60), bg=color).pack(pady=5)
    tk.Label(frame, text=explanation, font=("Helvetica", 14), bg=color).pack(pady=5)

    # Back to Dashboard button
    tk.Button(frame, text="Back to Dashboard", command=lambda: show_frame(frames["Dashboard"])).pack(pady=20)

    # Legend
    tk.Label(frame, text="Mood Score Legend", font=("Helvetica", 16, "bold"), bg=color).pack(pady=10)
    
    legend_frame = tk.Frame(frame, bg=color)
    legend_frame.pack()

    legend_items = [
        ("0–4: Minimal or No Depression", "lightgreen"),
        ("5–9: Mild Depression", "lightyellow"),
        ("10–14: Moderate Depression", "orange"),
        ("15–19: Moderately Severe Depression", "tomato"),
        ("20–27: Severe Depression", "red")
    ]

    for text, col in legend_items:
        row = tk.Frame(legend_frame, bg=color)
        row.pack(anchor="w", pady=2)
        tk.Label(row, width=2, height=1, bg=col).pack(side="left", padx=5)
        tk.Label(row, text=text, font=("Helvetica", 12), bg=color).pack(side="left")


# Initial setup calls
setup_welcome()
setup_signup()
setup_login()

show_frame(frames["Welcome"])
root.mainloop()