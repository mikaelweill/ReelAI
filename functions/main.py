# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

import firebase_functions.https_fn as https_fn
from firebase_admin import initialize_app, auth
from firebase_admin.auth import EmailAlreadyExistsError
import os

initialize_app()

@https_fn.on_call()
def send_magic_link_email(request):
    data = request.data
    email = data.get('email')
    
    if not email:
        return {'error': 'Email is required'}
        
    try:
        # Generate a sign-in link
        action_code_settings = auth.ActionCodeSettings(
            url=f'https://relai.page.link/finishSignUp?email={email}',
            handle_code_in_app=True,
            ios_bundle_id='com.reelai.app',
            android_package_name='com.reelai.app',
            android_install_app=True,
            android_minimum_version='12'
        )
        
        link = auth.generate_sign_in_with_email_link(
            email,
            action_code_settings
        )
        
        return {
            'success': True,
            'message': 'Magic link sent successfully',
            'link': link
        }
        
    except Exception as e:
        return {
            'error': str(e)
        }

# initialize_app()
#
#
# @https_fn.on_request()
# def on_request_example(req: https_fn.Request) -> https_fn.Response:
#     return https_fn.Response("Hello world!")