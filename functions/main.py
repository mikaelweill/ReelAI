# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

import firebase_functions.https_fn as https_fn
from firebase_admin import initialize_app, auth
import os

# Initialize without explicit credentials - it will use the default service account
initialize_app()

@https_fn.on_call()
def send_magic_link_email(request):
    try:
        data = request.data
        email = data.get('email')
        
        if not email:
            return {'error': 'Email is required', 'success': False}
            
        # Generate a sign-in link
        action_code_settings = auth.ActionCodeSettings(
            url=f'https://reelai-c8ef6.firebaseapp.com/finishSignUp?email={email}',
            handle_code_in_app=True,
            ios_bundle_id='com.reelai.app',
            android_package_name='com.reelai.reelai',
            android_install_app=True,
            android_minimum_version='12'
        )
        
        try:
            # This will both generate AND send the email
            auth.generate_sign_in_with_email_link(
                email,
                action_code_settings,
                app=None  # Use default Firebase app
            )
            
            return {
                'success': True,
                'message': 'Magic link sent successfully'
                # Don't return the link in production for security
            }
        except Exception as auth_error:
            print(f'Auth error: {str(auth_error)}')
            return {
                'error': 'Failed to generate sign-in link',
                'details': str(auth_error),
                'success': False
            }
        
    except Exception as e:
        print(f'Error in send_magic_link_email: {str(e)}')
        return {
            'error': str(e),
            'success': False
        }

# initialize_app()
#
#
# @https_fn.on_request()
# def on_request_example(req: https_fn.Request) -> https_fn.Response:
#     return https_fn.Response("Hello world!")