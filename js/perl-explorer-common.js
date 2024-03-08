// ########################################################################
$(document).ready(function () {
// ########################################################################
  $('#pe-status-message > button').on('click', function() {
    $(this).parent().css('display', 'none');
  });

});

// ########################################################################
function display_success_message(message) {
// ########################################################################
  display_status_message(message, 1);
}

// ########################################################################
function display_error_message(message) {
// ########################################################################
  display_status_message(message, 0);
}

// ########################################################################
function display_status_message(message, ok) {
// ########################################################################

  var classes = [ 'pe-error-message', 'pe-success-message'];
  
  // xor 1 ^ 1 = 0, 0 ^ 1 = 1 - clever eh?
  $('#pe-status-message').removeClass(classes[ok^1]);
  $('#pe-status-message').addClass(classes[ok]);
  
  $('#pe-status-message').css('display', 'inline-flex');
  $('#pe-status-message > span').text(message);
}
