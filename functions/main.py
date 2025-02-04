# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

import firebase_functions.https_fn as https_fn
from firebase_admin import initialize_app, auth
import os
import logging

# Add this at the top of the file
logger = logging.getLogger('firebase_functions')
logger.setLevel(logging.DEBUG)

# Initialize without explicit credentials - it will use the default service account
initialize_app()

@https_fn.on_call()
def send_magic_link_email(request):
    try:
        data = request.data
        email = data.get('email')
        
        if not email:
            return {'error': 'Email is required', 'success': False}
            
        logger.info(f'Attempting to send magic link to: {email}')
            
        try:
            # First create the user
            user = auth.create_user(
                email=email,
                email_verified=False
            )
            logger.info(f'Created new user: {user.uid}')
            
            # Generate the action code settings
            action_code_settings = auth.ActionCodeSettings(
                url=f'https://reelai-c8ef6.web.app/finishSignUp?email={email}',
                handle_code_in_app=True,
                ios_bundle_id='com.reelai.app',
                android_package_name='com.reelai.reelai',
                android_install_app=True,
                android_minimum_version='12',
                dynamic_link_domain='relai.page.link'
            )
            
            try:
                # First create the user
                user = auth.create_user(
                    email=email,
                    email_verified=False
                )
                logger.info(f'Created new user: {user.uid}')
                
                # Generate and send the verification link
                link = auth.generate_email_verification_link(
                    email,
                    action_code_settings
                )
                
                # The link contains the email verification URL
                # Now we need to manually send this email using a proper email service
                # For now, let's return the link so we can verify it's being generated
                logger.info(f'Generated verification link: {link}')
                
                return {
                    'success': True,
                    'message': 'Magic link generated successfully',
                    'userId': user.uid,
                    'link': link  # Return the link for debugging
                }
                
            except auth.EmailAlreadyExistsError:
                # For existing users, generate a sign-in link
                link = auth.generate_sign_in_with_email_link(
                    email,
                    action_code_settings
                )
                
                logger.info(f'Generated sign-in link for existing user: {link}')
                
                return {
                    'success': True,
                    'message': 'Magic link generated successfully',
                    'link': link  # Return the link for debugging
                }
            
        except Exception as auth_error:
            logger.error(f'Detailed auth error: {str(auth_error)}')
            logger.error(f'Auth error type: {type(auth_error)}')
            return {
                'error': 'Failed to send sign-in link',
                'details': str(auth_error),
                'success': False
            }
        
    except Exception as e:
        logger.error(f'Detailed error in send_magic_link_email: {str(e)}')
        logger.error(f'Error type: {type(e)}')
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