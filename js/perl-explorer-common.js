// ########################################################################
$(document).ready(function () {
// ########################################################################
  $('#pe-status-message > button').on('click', function() {
    close_modal('pe-status-message');
  });
  
});

// ########################################################################
function display_success_message(message, modal, callback) {
// ########################################################################
  display_status_message(message, 1, callback);
}

// ########################################################################
function display_error_message(message, modal, callback) {
// ########################################################################
  display_status_message(message, 0, callback);
}

// ########################################################################
function display_status_message(message, ok, callback) {
// ########################################################################

  var classes = [ 'pe-error-message', 'pe-success-message'];
  
  // xor 1 ^ 1 = 0, 0 ^ 1 = 1 - clever eh?
  $('#pe-status-message').removeClass(classes[ok^1]);
  $('#pe-status-message').addClass(classes[ok]);
  
  $('div.pe-status-message-container span').text(message);
  open_modal('pe-status-message', callback);
}

// ########################################################################
function open_modal(modal, callback) {
// ########################################################################

  $('#' + modal + ' > button').on('click', function() {
    close_modal(modal);

    if ( callback ) {
      callback();
    }
  });

  $('#' + modal).css('display', 'inline-block');

  $('body').addClass('modal-enabled');
  $('.overlay').toggle();
}

// ########################################################################
function close_modal(modal) {
// ########################################################################
  $('#' + modal).css('display', 'none');
  $('body').removeClass('modal-enabled');
  $('.overlay').toggle();
}


