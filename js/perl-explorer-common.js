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
  
  $('div.pe-status-message-container span').html(message);

  var icon_list = [ ['far','fa-frown','fa-lg'], ['fa', 'fa-thumbs-up fa-lg']];
  var icons = icon_list[ok];
  
  var icon = $('div.pe-status-message-container i');
  $(icon).removeClass();
  $(icon).addClass('pe-status-message-icon');
  
  icons.forEach(function(icon_class, index) {
    $(icon).addClass(icon_class);
  });
  
  open_modal('pe-status-message', callback);
}

// ########################################################################
function open_modal(modal, callback) {
// ########################################################################

  if ( callback ) {
    $('#' + modal + ' > button').on('click', function() {
      
      if ( callback ) {
        callback();
      }
    });
  }
  
  console.log('opening modal ' + modal);
  
  $('#' + modal).css('display', 'inline-block');

  $('body').addClass('modal-enabled');

  $('.overlay').css('display', 'block');
}

// ########################################################################
function close_modal(modal) {
// ########################################################################
  console.log('closing modal ' + modal);

  $('#' + modal).css('display', 'none');

  $('body').removeClass('modal-enabled');

  $('.overlay').css('display', 'none');
}


