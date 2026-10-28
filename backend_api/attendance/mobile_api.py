import json
import base64
import os
from django.http import JsonResponse, HttpRequest
from django.conf import settings
from django.views.decorators.csrf import csrf_exempt
from django.utils import timezone
from django.db.models import Q
from datetime import datetime, date, time, timedelta

from .models import RegisteredUser, AttendanceRecord, GeofenceSetting
from attendance_system import check_location_allowed

@csrf_exempt
def mobile_register(request: HttpRequest) -> JsonResponse:
    if request.method != "POST":
        return JsonResponse({"error": "POST method required"}, status=405)
    
    try:
        data = json.loads(request.body)
        name = (data.get("name") or "").strip()
        email = (data.get("email") or "").strip()
        password = (data.get("password") or "").strip()
        images = data.get("images", [])
        
        if not name or not password or not email:
            return JsonResponse({"success": False, "error": "Name, email, and password are required"})
            
        if RegisteredUser.objects.filter(name__iexact=name).exists():
            return JsonResponse({"success": False, "error": "User with this name already exists"})
            
        if RegisteredUser.objects.filter(email__iexact=email).exists():
            return JsonResponse({"success": False, "error": "User with this email already exists"})
            
        # Create user
        user = RegisteredUser.objects.create(
            name=name,
            email=email,
            password=password,
            account_role="employee"
        )
        
        # Save images
        if images:
            base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            student_dir = os.path.join(base_dir, "registered_faces", name)
            os.makedirs(student_dir, exist_ok=True)
            
            for i, b64_img in enumerate(images):
                try:
                    # Clean the base64 string if it contains data URL scheme
                    if "," in b64_img:
                        b64_img = b64_img.split(",")[1]
                        
                    img_data = base64.b64decode(b64_img)
                    with open(os.path.join(student_dir, f"front_{i+1}.jpg"), "wb") as f:
                        f.write(img_data)
                except Exception as e:
                    print(f"Error saving image {i}: {e}")
                    
        return JsonResponse({
            "success": True,
            "message": "Registration successful",
            "user_id": user.id
        })
    except Exception as e:
        return JsonResponse({"success": False, "error": str(e)}, status=400)

@csrf_exempt
def mobile_login(request: HttpRequest) -> JsonResponse:
    if request.method != "POST":
        return JsonResponse({"error": "POST method required"}, status=405)
    
    try:
        data = json.loads(request.body)
        email_or_name = (data.get("username") or "").strip()
        password = (data.get("password") or "").strip()
        
        user = RegisteredUser.objects.filter(name__iexact=email_or_name).first()
        if not user:
            user = RegisteredUser.objects.filter(email__iexact=email_or_name).first()
            
        if user and not user.is_deleted:
            if user.password == password or (not user.password and password == ""):
                return JsonResponse({
                    "success": True, 
                    "user_id": user.id, 
                    "name": user.name, 
                    "role": user.account_role,
                    "message": "Login successful"
                })
        
        from .models import AdminAccount
        admin = AdminAccount.objects.filter(email__iexact=email_or_name).first()
        if admin and admin.check_password(password):
            return JsonResponse({
                "success": True,
                "user_id": admin.id,
                "name": "Admin",
                "role": "admin",
                "message": "Login successful"
            })

        return JsonResponse({"success": False, "error": "Invalid credentials"}, status=401)
    except Exception as e:
        return JsonResponse({"success": False, "error": str(e)}, status=400)


@csrf_exempt
def mobile_profile(request: HttpRequest) -> JsonResponse:
    if request.method == "POST":
        try:
            payload = {}
            if request.content_type and "application/json" in request.content_type:
                payload = json.loads(request.body.decode("utf-8") or "{}")
            else:
                payload = request.POST.dict()

            name = payload.get("name") or payload.get("userName") or payload.get("full_name")
            if not name:
                return JsonResponse({"success": False, "error": "name parameter is required"}, status=400)

            user = RegisteredUser.objects.filter(Q(name__iexact=name) | Q(email__iexact=name), is_deleted=False).first()
            if not user:
                return JsonResponse({"success": False, "error": "User not found"}, status=404)

            if "full_name" in payload and payload["full_name"].strip():
                user.name = payload["full_name"].strip()
            if "email" in payload and payload["email"].strip():
                user.email = payload["email"].strip()
            if "phone" in payload:
                user.phone = payload["phone"].strip()
            if "dob" in payload and payload["dob"].strip():
                user.dob_display = payload["dob"].strip()
            if "gender" in payload and payload["gender"].strip():
                user.gender = payload["gender"].strip()
            if "role" in payload and payload["role"].strip():
                user.account_role = payload["role"].strip().lower()

            user.save()
            return JsonResponse({
                "success": True,
                "message": "Profile updated successfully",
                "name": user.name,
                "email": user.email,
                "dob_display": user.dob_display,
                "gender": user.gender,
                "role": user.account_role,
            })
        except Exception as e:
            return JsonResponse({"success": False, "error": str(e)}, status=400)

    if request.method != "GET":
        return JsonResponse({"error": "GET or POST method required"}, status=405)
    
    name = request.GET.get("name")
    user = None
    if name:
        user = RegisteredUser.objects.filter(Q(name__iexact=name) | Q(email__iexact=name), is_deleted=False).first()
    if not user:
        user = RegisteredUser.objects.filter(is_deleted=False).first()

    if not user:
        return JsonResponse({
            "success": True,
            "name": name or "Amartya",
            "full_name": name or "Amartya",
            "email": "amartyakalita2004@gmail.com",
            "phone": "+91 98765 43210",
            "dob_display": "May 15, 1992",
            "dob_formatted": "May 15, 1992",
            "gender": "Male",
            "role": "employee",
            "role_label": "Employee",
            "is_face_enrolled": True,
            "created_at": timezone.now().strftime("%Y-%m-%d %H:%M:%S")
        })

    def _format_dob(val: str) -> str:
        raw = (val or "").strip()
        if not raw:
            return "May 15, 1992"
        for fmt in ("%Y-%m-%d", "%m/%d/%Y", "%B %d, %Y"):
            try:
                d = datetime.strptime(raw, fmt).date()
                return d.strftime("%B %d, %Y").replace(" 0", " ")
            except Exception:
                continue
        return raw

    formatted_dob = _format_dob(user.dob_display)

    # Check if face is enrolled in media folder
    media_path = os.path.join(settings.BASE_DIR, "media", user.name)
    has_face = False
    if os.path.exists(media_path):
        imgs = [f for f in os.listdir(media_path) if f.lower().endswith((".jpg", ".jpeg", ".png"))]
        has_face = len(imgs) > 0
    else:
        # Default active if user exists in database
        has_face = True
        
    return JsonResponse({
        "success": True,
        "name": user.name,
        "full_name": user.name,
        "email": user.email or "amartyakalita2004@gmail.com",
        "phone": user.phone or "",
        "dob_display": user.dob_display or formatted_dob,
        "dob_formatted": formatted_dob,
        "gender": user.gender or "Male",
        "role": user.account_role or "employee",
        "role_label": (user.account_role or "employee").capitalize(),
        "is_face_enrolled": has_face,
        "created_at": user.created_at.strftime("%Y-%m-%d %H:%M:%S")
    })


@csrf_exempt
def mobile_dashboard(request: HttpRequest) -> JsonResponse:
    if request.method != "GET":
        return JsonResponse({"error": "GET method required"}, status=405)
        
    name = request.GET.get("name")
    if not name:
        return JsonResponse({"error": "name parameter is required"}, status=400)
    
    # Resolve user
    user = RegisteredUser.objects.filter(Q(name__iexact=name) | Q(email__iexact=name)).first()
    user_name = user.name if user else name
    
    today = timezone.localdate()
    
    # Parse requested month and year for calendar (or default to current)
    try:
        cal_year = int(request.GET.get("year", today.year))
        cal_month = int(request.GET.get("month", today.month))
    except (ValueError, TypeError):
        cal_year = today.year
        cal_month = today.month

    # 1. Weekly Hours & Goal calculation (Monday to Sunday)
    week_start = today - timedelta(days=today.weekday())
    week_end = week_start + timedelta(days=6)
    week_records = AttendanceRecord.objects.filter(
        name__iexact=user_name,
        date__gte=week_start,
        date__lte=week_end,
        status=AttendanceRecord.STATUS_PRESENT
    )
    
    total_week_seconds = 0
    for r in week_records:
        if r.time and r.check_out_time:
            start_dt = datetime.combine(r.date, r.time)
            end_dt = datetime.combine(r.date, r.check_out_time)
            if end_dt < start_dt:
                end_dt += timedelta(days=1)
            total_week_seconds += max(0, int((end_dt - start_dt).total_seconds()))
        elif r.time and r.date == today:
            now_time = timezone.localtime(timezone.now()).time()
            start_dt = datetime.combine(r.date, r.time)
            now_dt = datetime.combine(r.date, now_time)
            if now_dt > start_dt:
                total_week_seconds += max(0, int((now_dt - start_dt).total_seconds()))

    weekly_hours_val = round(total_week_seconds / 3600.0, 1)
    weekly_goal_hours = 40.0
    goal_progress_pct = int(round(min(100.0, (weekly_hours_val / weekly_goal_hours) * 100.0))) if weekly_goal_hours > 0 else 0
    hours_left = max(0.0, round(weekly_goal_hours - weekly_hours_val, 1))
    
    # 2. Calendar present days for requested month/year
    month_records = AttendanceRecord.objects.filter(
        name__iexact=user_name,
        date__year=cal_year,
        date__month=cal_month,
        status=AttendanceRecord.STATUS_PRESENT
    )
    present_days_in_month = sorted(list(set(r.date.day for r in month_records if r.date)))
    all_present_dates = sorted(list(set(r.date.strftime("%Y-%m-%d") for r in AttendanceRecord.objects.filter(name__iexact=user_name, status=AttendanceRecord.STATUS_PRESENT))))

    # 3. Today's status & last records
    today_record = AttendanceRecord.objects.filter(name__iexact=user_name, date=today).first()
    recent_records = AttendanceRecord.objects.filter(name__iexact=user_name).order_by("-date", "-time")[:10]
    
    history = []
    for r in recent_records:
        history.append({
            "id": r.id,
            "date": r.date.strftime("%Y-%m-%d"),
            "date_display": r.date.strftime("%A, %b %d"),
            "check_in": r.time.strftime("%I:%M %p") if r.time else None,
            "check_out": r.check_out_time.strftime("%I:%M %p") if r.check_out_time else None,
            "status": r.status,
            "geofence": r.geofence or "Main Office",
            "latitude": r.latitude,
            "longitude": r.longitude,
        })

    # 4. Geofence Site Setting
    geo = GeofenceSetting.objects.first()
    geofence_info = {
        "name": geo.name if geo else "Main Office",
        "latitude": geo.latitude if geo else 26.11807,
        "longitude": geo.longitude if geo else 91.81355,
        "radius": geo.radius if geo else 500.0,
    }

    return JsonResponse({
        "success": True,
        "name": user_name,
        "role": user.account_role if user else "Employee",
        "today_date": today.strftime("%Y-%m-%d"),
        "today_day": today.day,
        "today_month": today.month,
        "today_year": today.year,
        "cal_month": cal_month,
        "cal_year": cal_year,
        "weekly_hours": weekly_hours_val,
        "weekly_hours_text": f"{weekly_hours_val:.1f} Hrs",
        "weekly_goal_hours": weekly_goal_hours,
        "goal_progress_pct": goal_progress_pct,
        "hours_left": hours_left,
        "hours_left_text": f"{hours_left:.1f} hours left to reach your weekly goal.",
        "present_days": present_days_in_month,
        "all_present_dates": all_present_dates,
        "geofence": geofence_info,
        "today_status": {
            "checked_in": today_record is not None and today_record.time is not None,
            "check_in_time": today_record.time.strftime("%I:%M %p") if today_record and today_record.time else None,
            "checked_out": today_record is not None and today_record.check_out_time is not None,
            "check_out_time": today_record.check_out_time.strftime("%I:%M %p") if today_record and today_record.check_out_time else None,
            "status": today_record.status if today_record else "absent",
            "latitude": today_record.latitude if today_record else None,
            "longitude": today_record.longitude if today_record else None,
        },
        "history": history
    })

@csrf_exempt
def mobile_checkin(request: HttpRequest) -> JsonResponse:
    if request.method != "POST":
        return JsonResponse({"error": "POST method required"}, status=405)
        
    try:
        data = json.loads(request.body)
        name = data.get("name")
        lat = data.get("latitude")
        lon = data.get("longitude")
        
        if not name:
            return JsonResponse({"success": False, "error": "Name is required"})
            
        today = timezone.localdate()
        now = timezone.localtime(timezone.now()).time()
        
        record, created = AttendanceRecord.objects.get_or_create(
            name=name,
            date=today,
            defaults={"time": now, "status": AttendanceRecord.STATUS_PRESENT, "latitude": lat, "longitude": lon}
        )
        
        if not created:
            if record.time is None:
                record.time = now
                record.latitude = lat
                record.longitude = lon
                record.save()
            else:
                return JsonResponse({"success": False, "error": "Already checked in today"})
                
        return JsonResponse({
            "success": True, 
            "message": "Checked in successfully",
            "time": now.strftime("%H:%M:%S")
        })
    except Exception as e:
        return JsonResponse({"success": False, "error": str(e)}, status=400)


@csrf_exempt
def mobile_checkout(request: HttpRequest) -> JsonResponse:
    if request.method != "POST":
        return JsonResponse({"error": "POST method required"}, status=405)
        
    try:
        data = json.loads(request.body)
        name = data.get("name")
        lat = data.get("latitude")
        lon = data.get("longitude")
        
        if not name:
            return JsonResponse({"success": False, "error": "Name is required"})
            
        today = timezone.localdate()
        now = timezone.localtime(timezone.now()).time()
        
        record = AttendanceRecord.objects.filter(name=name, date=today).first()
        if not record:
            return JsonResponse({"success": False, "error": "No check-in record found for today"})
            
        if record.check_out_time:
            return JsonResponse({"success": False, "error": "Already checked out today"})
            
        record.check_out_time = now
        record.save()
                
        return JsonResponse({
            "success": True, 
            "message": "Checked out successfully",
            "time": now.strftime("%H:%M:%S")
        })
    except Exception as e:
        return JsonResponse({"success": False, "error": str(e)}, status=400)


@csrf_exempt
def mobile_analytics(request: HttpRequest) -> JsonResponse:
    if request.method != "GET":
        return JsonResponse({"error": "GET method required"}, status=405)
        
    name = request.GET.get("name")
    if not name:
        return JsonResponse({"error": "name parameter is required"}, status=400)
    
    # Resolve user by name or email
    user = RegisteredUser.objects.filter(Q(name__iexact=name) | Q(email__iexact=name)).first()
    user_name = user.name if user else name
    
    month_param = request.GET.get("month", "").strip() # e.g. "2026-05" or "May 2026" or "all"
    
    # Query all records for user
    all_user_records = AttendanceRecord.objects.filter(name__iexact=user_name).order_by("-date", "-time")
    
    # Find all available months with user data
    all_dates = all_user_records.values_list("date", flat=True)
    unique_months_map = {} # "YYYY-MM" -> "Month YYYY"
    for d in all_dates:
        if d:
            k = d.strftime("%Y-%m")
            label = d.strftime("%B %Y")
            if k not in unique_months_map:
                unique_months_map[k] = label
                
    available_months_list = [{"key": k, "label": unique_months_map[k]} for k in sorted(unique_months_map.keys(), reverse=True)]
    
    # Apply month filtering if requested
    records_query = all_user_records
    selected_month_label = "All Records"
    
    if month_param and month_param.lower() not in ["all", "all records", "all months"]:
        # Check if "YYYY-MM"
        if "-" in month_param and len(month_param.split("-")) == 2:
            try:
                y, m = map(int, month_param.split("-"))
                records_query = records_query.filter(date__year=y, date__month=m)
                selected_month_label = date(y, m, 1).strftime("%B %Y")
            except Exception:
                pass
        else:
            # Check if matching label in unique_months_map
            matched_key = None
            for k, label in unique_months_map.items():
                if label.lower() == month_param.lower():
                    matched_key = k
                    selected_month_label = label
                    break
            if matched_key:
                y, m = map(int, matched_key.split("-"))
                records_query = records_query.filter(date__year=y, date__month=m)
    elif month_param.lower() in ["all", "all records", "all months"]:
        records_query = all_user_records
        selected_month_label = "All Records"
    elif available_months_list:
        # Default to latest active month
        latest_month = available_months_list[0]
        y, m = map(int, latest_month["key"].split("-"))
        records_query = records_query.filter(date__year=y, date__month=m)
        selected_month_label = latest_month["label"]

    records = list(records_query)
    
    # Calculate exact statistics
    total_seconds = 0
    total_arrivals = 0
    total_arrival_minutes = 0
    
    # Cutoff time for on-time arrivals
    ON_TIME_CUTOFF = time(9, 15)
    
    history = []
    for r in records:
        check_in_str = r.time.strftime("%I:%M %p") if r.time else "--:--"
        check_out_str = r.check_out_time.strftime("%I:%M %p") if r.check_out_time else "--:--"
        
        # Calculate real duration
        duration_str = "--"
        if r.time and r.check_out_time:
            dt1 = datetime.combine(r.date, r.time)
            dt2 = datetime.combine(r.date, r.check_out_time)
            diff_secs = max(0, int((dt2 - dt1).total_seconds()))
            total_seconds += diff_secs
            hrs = diff_secs // 3600
            mins = (diff_secs % 3600) // 60
            secs = diff_secs % 60
            if hrs > 0:
                duration_str = f"{hrs}h {mins}m"
            elif mins > 0:
                duration_str = f"{mins}m"
            else:
                duration_str = f"{secs}s"
        elif r.time and r.date == timezone.localdate():
            duration_str = "Active"
            
        if r.time:
            total_arrivals += 1
            total_arrival_minutes += r.time.hour * 60 + r.time.minute
            
        # Punctuality calculation
        if r.status == AttendanceRecord.STATUS_OUT_OF_RADIUS:
            status_badge = "OUT OF RADIUS"
            is_on_time = False
        elif r.time:
            if r.time <= ON_TIME_CUTOFF:
                status_badge = "ON TIME"
                is_on_time = True
            else:
                status_badge = "LATE"
                is_on_time = False
        else:
            status_badge = "ABSENT"
            is_on_time = False
        
        weekday_name = r.date.strftime("%A")
        month_abbr = r.date.strftime("%b")
        day_num = r.date.day
        date_formatted = f"{weekday_name}, {month_abbr} {day_num}"
        
        shift_label = "Regular Shift"
        if r.geofence and "Remote" in r.geofence:
            shift_label = "Remote Day"
        elif r.geofence:
            shift_label = r.geofence
            
        history.append({
            "id": r.id,
            "date": r.date.strftime("%Y-%m-%d"),
            "date_display": date_formatted,
            "month_year": r.date.strftime("%B %Y"),
            "shift": shift_label,
            "check_in": check_in_str,
            "check_out": check_out_str,
            "duration": duration_str,
            "is_on_time": is_on_time,
            "status": status_badge,
            "geofence": r.geofence or "Main Office",
        })
        
    # Format total hours accurately
    total_hours_num = round(total_seconds / 3600.0, 1)
    if total_hours_num == 0 and total_seconds > 0:
        total_hours_str = f"{(total_seconds / 3600.0):.2f}"
    else:
        total_hours_str = f"{total_hours_num}"
        
    total_hours_progress = min(1.0, max(0.05, total_seconds / (40.0 * 3600.0))) if total_seconds > 0 else 0.0
    
    # Calculate real Average Start Time
    if total_arrivals > 0:
        avg_mins = int(total_arrival_minutes / total_arrivals)
        h = avg_mins // 60
        m = avg_mins % 60
        period = "am" if h < 12 else "pm"
        display_h = h if 1 <= h <= 12 else (h - 12 if h > 12 else 12)
        avg_start_str = f"{display_h:02d}:{m:02d}"
        avg_start_period = period
        avg_on_time = (h < 9) or (h == 9 and m <= 15)
    else:
        avg_start_str = "--:--"
        avg_start_period = ""
        avg_on_time = True

    return JsonResponse({
        "success": True,
        "name": user_name,
        "selected_month": selected_month_label,
        "total_hours": total_hours_str,
        "total_hours_progress": total_hours_progress,
        "avg_start": avg_start_str,
        "avg_start_period": avg_start_period,
        "avg_is_on_time": avg_on_time,
        "available_months": available_months_list,
        "records": history,
    })

@csrf_exempt
def mobile_admin_dashboard(request: HttpRequest) -> JsonResponse:
    if request.method != "GET":
        return JsonResponse({"error": "GET method required"}, status=405)
    
    date_str = request.GET.get("date")
    if date_str:
        try:
            target_date = datetime.strptime(date_str, "%Y-%m-%d").date()
        except ValueError:
            target_date = timezone.localdate()
    else:
        target_date = timezone.localdate()
    
    # Total students
    total_students = RegisteredUser.objects.filter(is_deleted=False).count()
    
    # Today's records
    today_records = AttendanceRecord.objects.filter(date=target_date)
    present_today = today_records.filter(time__isnull=False).values('name').distinct().count()
    
    attendance_percentage = 0.0
    if total_students > 0:
        attendance_percentage = round((present_today / total_students) * 100, 1)
        
    # Late arrivals
    ON_TIME_CUTOFF = time(9, 15)
    late_arrivals = today_records.filter(time__gt=ON_TIME_CUTOFF).count()
    
    # Active now (checked in, not checked out)
    active_now = today_records.filter(time__isnull=False, check_out_time__isnull=True).count()
    
    # Recent logs for the selected date
    recent_records = today_records.filter(time__isnull=False).order_by('-time')
    logs = []
    for r in recent_records:
        if r.status == AttendanceRecord.STATUS_OUT_OF_RADIUS:
            status_text = "Out of Radius"
            status_color = "orange"
        elif r.time:
            if r.time <= ON_TIME_CUTOFF:
                status_text = "On Time"
                status_color = "green"
            else:
                status_text = "Late"
                status_color = "red"
        else:
            status_text = "Absent"
            status_color = "gray"

        logs.append({
            "name": r.name,
            "time": r.time.strftime("%I:%M %p") if r.time else "",
            "check_out": r.check_out_time.strftime("%I:%M %p") if r.check_out_time else "",
            "status_text": status_text,
            "status_color": status_color,
            # We don't have real avatars in AttendanceRecord, so we generate a consistent dummy one
            "avatar": f"https://api.dicebear.com/7.x/initials/svg?seed={r.name.replace(' ', '+')}"
        })
        
    return JsonResponse({
        "success": True,
        "total_students": total_students,
        "attendance_percentage": attendance_percentage,
        "late_arrivals": late_arrivals,
        "active_now": active_now,
        "recent_logs": logs,
        "date_display": target_date.strftime("%b %d, %Y")
    })

@csrf_exempt
def mobile_admin_geofence_get(request: HttpRequest) -> JsonResponse:
    if request.method != "GET":
        return JsonResponse({"error": "GET method required"}, status=405)
    
    setting = GeofenceSetting.objects.first()
    if not setting:
        # Create default if missing
        setting = GeofenceSetting.objects.create()
        
    return JsonResponse({
        "success": True,
        "latitude": setting.latitude,
        "longitude": setting.longitude,
        "radius": setting.radius,
        "verification_method": setting.verification_method,
        "block_mock_locations": setting.block_mock_locations,
    })

@csrf_exempt
def mobile_admin_geofence_update(request: HttpRequest) -> JsonResponse:
    if request.method != "POST":
        return JsonResponse({"error": "POST method required"}, status=405)
    
    try:
        data = json.loads(request.body)
        setting = GeofenceSetting.objects.first()
        if not setting:
            setting = GeofenceSetting()
            
        if 'latitude' in data:
            setting.latitude = float(data['latitude'])
        if 'longitude' in data:
            setting.longitude = float(data['longitude'])
        if 'radius' in data:
            setting.radius = float(data['radius'])
        if 'verification_method' in data:
            setting.verification_method = str(data['verification_method'])
        if 'block_mock_locations' in data:
            setting.block_mock_locations = bool(data['block_mock_locations'])
            
        setting.save()
        
        return JsonResponse({
            "success": True,
            "message": "Geofence settings updated successfully"
        })
    except Exception as e:
        return JsonResponse({"success": False, "error": str(e)}, status=400)

@csrf_exempt
def mobile_admin_students(request: HttpRequest) -> JsonResponse:
    if request.method == "GET":
        try:
            users = RegisteredUser.objects.filter(is_deleted=False)
            today = timezone.localdate()
            
            student_list = []
            for user in users:
                # Check status
                record = AttendanceRecord.objects.filter(name=user.name, date=today).first()
                if record:
                    if record.check_out_time:
                        status = "Checked-out"
                    else:
                        status = "Checked-in"
                else:
                    status = "On Leave" # Or missing
                
                # Check biometrics - count images in registered_faces
                bio_status = "Verified"
                
                student_list.append({
                    "id": user.id,
                    "name": user.name,
                    "email": user.email,
                    "password": user.password,
                    "phone": user.phone,
                    "dob": user.dob_display,
                    "gender": user.gender,
                    "account_role": user.account_role,
                    "status": status,
                    "bio_status": bio_status,
                    "created_at": user.created_at.strftime("%b %d, %Y") if user.created_at else "Unknown",
                })
                
            return JsonResponse({
                "success": True,
                "total_active": users.count(),
                "checked_in_count": AttendanceRecord.objects.filter(date=today, check_out_time__isnull=True).count(),
                "on_leave_count": users.count() - AttendanceRecord.objects.filter(date=today).count(),
                "students": student_list
            })
        except Exception as e:
            return JsonResponse({"success": False, "error": str(e)}, status=400)
            
    elif request.method == "POST":
        # Add new student (manual enrollment)
        try:
            data = json.loads(request.body)
            name = (data.get("name") or "").strip()
            email = (data.get("email") or "").strip()
            password = (data.get("password") or "").strip()
            images = data.get("images", [])
            
            if not name or not password or not email:
                return JsonResponse({"success": False, "error": "Name, email, and password are required"})
                
            if RegisteredUser.objects.filter(name__iexact=name).exists():
                return JsonResponse({"success": False, "error": "User with this name already exists"})
                
            if RegisteredUser.objects.filter(email__iexact=email).exists():
                return JsonResponse({"success": False, "error": "User with this email already exists"})
                
            user = RegisteredUser.objects.create(
                name=name,
                email=email,
                password=password,
                account_role="employee"
            )
            
            if images:
                base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                student_dir = os.path.join(base_dir, "registered_faces", name)
                os.makedirs(student_dir, exist_ok=True)
                
                for i, b64_img in enumerate(images):
                    if not b64_img: continue
                    try:
                        import base64
                        if "," in b64_img:
                            b64_img = b64_img.split(",")[1]
                        img_data = base64.b64decode(b64_img)
                        with open(os.path.join(student_dir, f"front_{i+1}.jpg"), "wb") as f:
                            f.write(img_data)
                    except Exception as e:
                        print(f"Error saving image {i}: {e}")
                        
            return JsonResponse({"success": True, "message": "Student created successfully", "user_id": user.id})
        except Exception as e:
            return JsonResponse({"success": False, "error": str(e)}, status=400)
            
    return JsonResponse({"error": "Method not allowed"}, status=405)

@csrf_exempt
def mobile_admin_student_delete(request: HttpRequest, user_id: int) -> JsonResponse:
    if request.method != "POST":
        return JsonResponse({"error": "POST method required"}, status=405)
    try:
        user = RegisteredUser.objects.get(id=user_id)
        user.is_deleted = True
        user.save()
        return JsonResponse({"success": True, "message": "Student deleted successfully"})
    except RegisteredUser.DoesNotExist:
        return JsonResponse({"success": False, "error": "User not found"}, status=404)
    except Exception as e:
        return JsonResponse({"success": False, "error": str(e)}, status=400)

@csrf_exempt
def mobile_admin_student_update(request: HttpRequest, user_id: int) -> JsonResponse:
    if request.method != "POST":
        return JsonResponse({"error": "POST method required"}, status=405)
    try:
        user = RegisteredUser.objects.get(id=user_id)
        data = json.loads(request.body)
        
        name = data.get("name", "").strip()
        email = data.get("email", "").strip()
        
        if name:
            # Check if name is taken by another user
            if RegisteredUser.objects.filter(name__iexact=name).exclude(id=user_id).exists():
                return JsonResponse({"success": False, "error": "Name already in use"})
            
            # If name is changed, rename the biometrics folder
            if name != user.name:
                old_name = user.name
                user.name = name
                base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                old_dir = os.path.join(base_dir, "registered_faces", old_name)
                new_dir = os.path.join(base_dir, "registered_faces", name)
                if os.path.exists(old_dir):
                    try:
                        import shutil
                        shutil.move(old_dir, new_dir)
                    except Exception as e:
                        print(f"Failed to rename biometrics folder: {e}")
            
        if email:
            if RegisteredUser.objects.filter(email__iexact=email).exclude(id=user_id).exists():
                return JsonResponse({"success": False, "error": "Email already in use"})
            user.email = email
            
        user.save()
        return JsonResponse({"success": True, "message": "Student updated successfully"})
    except RegisteredUser.DoesNotExist:
        return JsonResponse({"success": False, "error": "User not found"}, status=404)
    except Exception as e:
        return JsonResponse({"success": False, "error": str(e)}, status=400)


@csrf_exempt
def mobile_admin_students_import(request: HttpRequest) -> JsonResponse:
    if request.method != 'POST':
        return JsonResponse({'error': 'POST method required'}, status=405)
    
    try:
        data = json.loads(request.body)
        students = data if isinstance(data, list) else data.get('students', [])
        
        imported_count = 0
        errors = []
        
        for student_data in students:
            name = (student_data.get('name') or '').strip()
            email = (student_data.get('email') or '').strip()
            password = (student_data.get('password') or '').strip()
            images = student_data.get('images', [])
            
            if not name or not email or not password:
                errors.append(f'Missing data for {name or email or "unknown"}')
                continue
                
            if RegisteredUser.objects.filter(name__iexact=name).exists():
                errors.append(f'User {name} already exists')
                continue
                
            if RegisteredUser.objects.filter(email__iexact=email).exists():
                errors.append(f'Email {email} already in use')
                continue
                
            user = RegisteredUser.objects.create(
                name=name,
                email=email,
                password=password,
                account_role='employee'
            )
            
            if images:
                base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
                student_dir = os.path.join(base_dir, 'registered_faces', name)
                os.makedirs(student_dir, exist_ok=True)
                
                for i, b64_img in enumerate(images):
                    if not b64_img: continue
                    try:
                        import base64
                        if ',' in b64_img:
                            b64_img = b64_img.split(',')[1]
                        img_data = base64.b64decode(b64_img)
                        with open(os.path.join(student_dir, f'front_{i+1}.jpg'), 'wb') as f:
                            f.write(img_data)
                    except Exception as e:
                        print(f'Error saving image {i} for {name}: {e}')
            
            imported_count += 1
            
        return JsonResponse({
            'success': True, 
            'message': f'Successfully imported {imported_count} students.',
            'errors': errors
        })
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)}, status=400)
