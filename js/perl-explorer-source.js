// ########################################################################
// (c) Copyright 2024, TBC Development Group, LLC
// All rights reserved.
// ########################################################################

// ########################################################################
$(document).ready(function () {
// ########################################################################

  var comments = $('span.comment').filter(function() {
    return  $(this).text().indexOf('no critic') > -1;
  });

  // ###################################################################
  // light up no critic - possible TODOs?
  // ###################################################################
  $(comments).each(function() {
    $(this).addClass('pe-critic');
  });

  // ###################################################################
  // TODO
  // ###################################################################
  $('.linenum').on('click', function() {
    $('#pe-todo-text').val('');

    $('#todo-linenum').val($(this).text());
    open_modal('pe-todo-container');
  });

  $('#pe-todo-cancel').on('click', function() {
    close_modal('pe-todo-container');
  });

  $('#pe-todo-save').on('click', function() {
    save_todo();
    close_modal('pe-todo-container');
  });

  // ###################################################################
  // dependencies dropdown
  // ###################################################################

  $('#pe-dependencies').on('change', function () {
    var is_local = $('#pe-dependencies').val();
    
    module = $('#pe-dependencies option:selected').text();
    
    if ( is_local == "1" ) {
      window.open('/explorer/source/' + module, '_blank');
    }
    else {
      window.open('/explorer/pod/' + module, '_blank');
    }
    
  });

  location.href = '#pe-1'; // always start at first line
  
  // ###################################################################
  // subs dropdown
  // ###################################################################
  $('#pe-subs').on('change', function() {

    if ( !this.value ) {
      location.href = '#pe-1';
      
      $('.pe-linenum-selected').each(function () { $(this).removeClass('pe-linenum-selected'); } );
      
      return;
    }
    
    var linenum = this.value + ':';

    var anchor = '#pe-' + parseInt(this.value);

    var elem = $('.linenum').filter(function () { return $(this).text().indexOf(linenum) > -1});
    
    $('.pe-linenum-selected').each(function () { $(this).removeClass('pe-linenum-selected'); } );
    
    $(elem).addClass('pe-linenum-selected');

    location.href = anchor;
    
    elem = $(elem).parent().next();
        
    while (elem && ! $(elem).is('a') ) {
      console.log($(elem).attr('class'));
      $(elem).addClass('pe-linenum-selected');
      elem = $(elem).next();
    }
  });
});


// #####################################################################
function save_todo() {
// #####################################################################
  var module = $('title').text();

  var data = {
    todos : [ $('#todo-linenum').val(), $('#pe-todo-text').val() ],
    module: $('title').text()
  };
  
  console.log(data);
  
  $('body').addClass('loading');
  
  $.ajax({
    url: '/explorer/source/todos',
    dataType: 'json',
    data: JSON.stringify(data),
    method: 'POST',
    contentType: 'application/json'
  }).done(function (data) {
    $('body').removeClass('loading');

    display_success_message('Successfully saved your TODO!', function () {
      location.reload(0);
    });

    return true;
  }).fail(function($xhr, status, error) {

    $('body').removeClass('loading');
    display_error_message('Error saving your TODOs!');
    
    return false;
  });

  
  return;
}
