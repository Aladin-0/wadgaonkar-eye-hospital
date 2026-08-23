"""
Custom DRF exception handler for standardized error responses.
"""
from rest_framework.views import exception_handler
from rest_framework.response import Response
from rest_framework import status

def custom_exception_handler(exc, context):
    response = exception_handler(exc, context)

    if response is not None:
        custom_data = {
            'success': False,
            'status_code': response.status_code,
            'errors': response.data,
            'message': 'An error occurred while processing your request.',
        }
        if isinstance(response.data, dict) and 'detail' in response.data:
            custom_data['message'] = response.data['detail']
        response.data = custom_data
    else:
        # Unhandled server error
        return Response({
            'success': False,
            'status_code': status.HTTP_500_INTERNAL_SERVER_ERROR,
            'message': str(exc),
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    return response
