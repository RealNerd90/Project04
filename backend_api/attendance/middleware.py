import django.utils.timezone as tz
from django.http import HttpResponse
from .models import SystemSetting


class CorsMiddleware:
    """Allow cross-origin requests from web, emulators, and mobile clients."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.method == "OPTIONS":
            response = HttpResponse()
        else:
            response = self.get_response(request)

        response["Access-Control-Allow-Origin"] = "*"
        response["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
        response["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With"
        return response


class TimezoneMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Dynamic timezone setting was removed from SystemSetting model.
        # System will now use the default TIME_ZONE from settings.py.
        tz.deactivate()

        response = self.get_response(request)
        return response

