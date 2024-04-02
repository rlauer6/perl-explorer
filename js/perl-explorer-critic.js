// perl-explorer v1.0
// (C) Copyright 2024 - TBC Development Group, LLC
// All rights reserved

var repo;

// #####################################################################
$(document).ready(function () {
// #####################################################################
  var line_numbers = {};

  repo = $('#pe-repo').val();
  
  $('.severity').each(function () {
    $(this).addClass('sev-' + $(this).text())
  });

  if ( $('.pe-critic-todo').length > 0 ) {
    enable_save_button();
  }
  else {
    disable_save_button();
  }
  
  $('.pe-critic-policy').on('click', function() {
    var policy = $(this).text();

    $('#diagnostic > h1').text(policy);

    var policy_description = diagnostics[policy];

    console.log(policy);
    console.log(policy_description);

    $('#diagnostic div > span').html(policy_description);

    open_modal('diagnostic');
  });

  $('.pe-critic-source.tooltip, .pe-critic-description.tooltip').hover(
    function () {
      var spans = $(this).children('span');
      
      var tool_tip = $(spans[0]).text();
      
      if ( spans.length == 2) {
        tool_tip = $(spans[1]).text();
      }
            
      set_tool_tip(tool_tip, $(this).offset());
    },
    function () {
      $('#tooltip-container').css('display', 'none');
    });

  $('.pe-critic-linenumber').on('click', function() {
    if ( $(this).hasClass('pe-critic-todo') ) {
      update_todo_status(this, 0); // remove
    }
    else {
      update_todo_status(this, 1); // add
    }
                                
  });
    
  $('.pe-critic-linenumber').hover(
    
    function () {
      var line_number_text = $(this).text();

      var offset = $(this).offset();
      
      if ( line_numbers[line_number_text] ) {
        set_tool_tip(line_numbers[line_number_text], offset);
      }
      else {
        var title = $('title').text();
        var uri = '/explorer/' + repo + '/source/lines/' + title + '?lines=5&line_number=' + line_number_text;
        
        $.ajax({
          url: uri
        }).done(function (data) {
          line_numbers[line_number_text] = data.join('');
          set_tool_tip(line_numbers[line_number_text], offset);
        });
      }
    },
    function () {
      reset_tool_tip();
    });

  $('#critic').DataTable({
    bAutoWidth: false,
    columns: [  null, null, null, null, {width: '20%'}, { width: '50%' }]
  });

});

// #####################################################################
function enable_save_button() {      
// #####################################################################
  $('#pe-save-button').addClass('pe-button-enabled');
  $('#pe-save-button').removeClass('pe-button-disabled');
  $('#pe-save-button').on('click', save_todos);
}

// #####################################################################
function disable_save_button() {
// #####################################################################
    $('#pe-save-button').addClass('pe-button-disabled');
    $('#pe-save-button').removeClass('pe-button-enabled');
    $('#pe-save-button').off('click');
}

// #####################################################################
function update_todo_status(line, add_or_delete)  {
// #####################################################################
  var status = $('.pe-critic-todo').length; // how many do we have?
  
  if ( add_or_delete ) {
    $(line).addClass('pe-critic-todo');
    $(line).find('i').addClass(['fa', 'fa-clipboard-list', 'fa-lg']);

    if ( status == 0 ) {
      enable_save_button();
    }
  }
  else {
    $(line).removeClass('pe-critic-todo');
    $(line).find('i').removeClass(['fa', 'fa-clipboard-list', 'fa-lg']);

    if (status == 1 ) {
      disable_save_button();
    }
  }

  return;
}


// #####################################################################
function set_tool_tip(text, offset) {
// #####################################################################
  
  $('#tooltip-container').css({
    marginLeft: 0,
    marginTop: 0,
    top: offset.top + 65,
    left: offset.left + 50
  }).appendTo('body');
  
  $('#tooltip-container').html(text);
  $('#tooltip-container').css('display', 'block');
}

// #####################################################################
function reset_tool_tip () {
// #####################################################################
  $('#tooltip-container').css('display', 'none');
}


// #####################################################################
function save_todos() {
// #####################################################################
  var todos = [];
  
  $('.pe-critic-todo').each(function() {

    var linenum = $(this).text();
    var policy =  $(this).siblings('.pe-critic-policy').text();

    console.log(linenum + ':' + policy);
    todos.push(linenum);
    todos.push(policy);
  });
   
  $.ajax({
    url: '/explorer/source/todos/critic',
    dataType: 'json',
    data: JSON.stringify({
      todos : todos,
      module: $('title').text()
    }),
    method: 'POST',
    contentType: 'application/json'
  }).done(function (data) {

    display_success_message('Successfully saved your TODOs!');

    console.log(data);

    return true;
  }).fail(function($xhr, status, error) {

    console.log($xhr);
    console.log(status);
    console.log(error);
    
    display_error_message('Error saving your TODOs!');
    
    return false;
  });
    
}
