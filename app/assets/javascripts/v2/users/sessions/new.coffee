setupSwitchSignIn = ->
  $('.switch-to-federated').click ->
    switchSignIn('federated')
  $('.switch-to-email').click ->
    switchSignIn('email')

switchSignIn = (method) ->
  federatedLoginBlock = $('#sign-in-with-federated')
  emailLoginBlock = $('#sign-in-with-email')
  federatedLoginLink = $('a.switch-to-federated')
  emailLoginLink = $('a.switch-to-email')

  if method == 'email'
    federatedLoginBlock.addClass('hidden-xs-up')
    emailLoginBlock.removeClass('hidden-xs-up')
    federatedLoginLink.removeClass('hidden-xs-up')
    emailLoginLink.addClass('hidden-xs-up')
  else if method == 'federated'
    federatedLoginBlock.removeClass('hidden-xs-up')
    emailLoginBlock.addClass('hidden-xs-up')
    federatedLoginLink.addClass('hidden-xs-up')
    emailLoginLink.removeClass('hidden-xs-up')
  else
    console.error("Unknown method of login requested: #{method}")

# Callback function for invisible recaptcha present in the registration form. This callback is called when the recaptcha
# verification is completed successfully - so a flag is set using a data attribute to indicate this.
window.handleSignInWithEmailButton = ->
  signInForm = $('#new_user_sign_in')
  signInForm.data('recaptchaComplete', 'true')
  signInForm.submit()

# Sets up the registration form to prevent submission if recaptcha verfication is incomplete, and trigger it manually.
setupSignInFormWithEmailHandler = ->
  $('#new_user_sign_in').submit (event) ->
    signInForm = $('#new_user_sign_in')

    return if signInForm.data('test')

    unless signInForm.data('recaptchaComplete')
      event.preventDefault()
      grecaptcha.reset()
      grecaptcha.execute()

$(document).on 'turbolinks:load', ->
  if $('#sign-in-with-email').length
    setupSwitchSignIn()
    setupSignInFormWithEmailHandler()
