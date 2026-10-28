import os

file_path = 'c:/Users/Hp/Documents/Project03/attendance/views.py'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

functions_to_exempt = [
    'def manual_login(request: HttpRequest)',
    'def signin_scan(request: HttpRequest)',
    'def attendance_checkin_scan(request: HttpRequest)',
    'def attendance_checkout_scan(request: HttpRequest)',
    'def register_face(request: HttpRequest)',
    'def upload_reminder_sound(request: HttpRequest)',
    'def delete_reminder_sound(request: HttpRequest, sound_id: int)'
]

for func in functions_to_exempt:
    if f"@csrf_exempt\n{func}" not in content and f"@csrf_exempt\n@require_POST\n{func}" not in content:
        # Check if it has @require_POST
        if f"@require_POST\n{func}" in content:
            content = content.replace(f"@require_POST\n{func}", f"@csrf_exempt\n@require_POST\n{func}")
        else:
            content = content.replace(func, f"@csrf_exempt\n{func}")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Success adding @csrf_exempt')
