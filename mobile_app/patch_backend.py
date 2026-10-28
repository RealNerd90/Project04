import os
import json

file_path = 'c:/Users/Hp/Documents/Project03/attendance/views.py'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

new_manual_login = '''def manual_login(request: HttpRequest) -> HttpResponse:
    """Manual email/password login (simple registry-based) with lockout."""
    from django.core.cache import cache
    if request.method == "POST":
        is_json = request.META.get("CONTENT_TYPE", "").startswith("application/json")
        if is_json:
            import json
            try:
                payload = json.loads(request.body.decode("utf-8") or "{}")
                email = (payload.get("username") or payload.get("email") or "").strip()
                password = (payload.get("password") or "").strip()
            except Exception:
                return JsonResponse({"success": False, "error": "Invalid JSON"}, status=400)
        else:
            email = (request.POST.get("email") or "").strip()
            password = (request.POST.get("password") or "").strip()
            
        if not email or not password:
            if is_json:
                return JsonResponse({"success": False, "error": "Please enter both email and password."}, status=400)
            return render(
                request,
                "manual_login.html",
                {"error": "Please enter both email and password.", "email": email},
                status=400,
            )

        email_key = email.lower()
        lockout_key = f"lockout_{email_key}"
        attempts_key = f"login_attempts_{email_key}"

        if cache.get(lockout_key):
            error_msg = "Maximum login attempts exceeded. Please try again after 5 minutes."
            if is_json:
                return JsonResponse({"success": False, "error": error_msg}, status=403)
            return render(
                request,
                "manual_login.html",
                {"error": error_msg, "email": email},
                status=403,
            )

        from .models import SystemSetting
        setting = SystemSetting.objects.first()
        max_attempts = setting.max_login_attempts if setting else 5

        def record_failed_attempt():
            attempts = cache.get(attempts_key, 0) + 1
            if attempts >= max_attempts:
                cache.set(lockout_key, True, timeout=300) # 5 minutes lockout
                cache.delete(attempts_key)
                return True # Locked out
            else:
                cache.set(attempts_key, attempts, timeout=3600) # Remember for 1 hour
                return False

        admin = AdminAccount.objects.filter(email__iexact=email).first()
        if admin and admin.check_password(password):
            cache.delete(attempts_key)
            request.session["is_admin"] = True
            request.session["display_name"] = "Admin"
            if is_json:
                return JsonResponse({"success": True, "name": "Admin", "role": "Admin"})
            return redirect("admin-dashboard")

        user = RegisteredUser.objects.filter(email__iexact=email, is_deleted=False).first()
        if not user or not user.password or user.password != password:
            locked = record_failed_attempt()
            error_msg = "Maximum login attempts exceeded. Please try again after 5 minutes." if locked else "Invalid email or password."
            if is_json:
                return JsonResponse({"success": False, "error": error_msg}, status=400 if not locked else 403)
            return render(
                request,
                "manual_login.html",
                {"error": error_msg, "email": email},
                status=400 if not locked else 403,
            )

        cache.delete(attempts_key)
        request.session["display_name"] = _normalize_display_name(user.name)
        request.session.pop("is_admin", None)
        if is_json:
            return JsonResponse({"success": True, "name": _normalize_display_name(user.name), "role": "User"})
        return redirect("dashboard")

    return render(request, "manual_login.html")
'''

start_idx = content.find('def manual_login(request: HttpRequest) -> HttpResponse:')
end_idx = content.find('def registration(request: HttpRequest) -> HttpResponse:')

new_content = content[:start_idx] + new_manual_login + '\n\n' + content[end_idx:]

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print('Success')
