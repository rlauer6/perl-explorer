// ########################################################################
// (c) Copyright 2024, TBC Development Group, LLC
// All rights reserved.
// ########################################################################

// ########################################################################
$(document).ready(function () {
// ########################################################################

  // disable context menu
  document.oncontextmenu = function ()  { return false };
  // close all folders
  
  // open root folder
  var first_div = $('#tree').children('div').first();
  first_div.toggle();
  $('#tree').children().first().find('.folder').each(function() { $(this).toggle();})
  
  var root = $('#tree').children().first();
  toggle_children(root.next());
  
  // show source
  $('.pe-source-file').on('click', function() {
    var id = $(this).attr('id');
    clear_context();
    var repo = $('title').text();
    var uri = '/explorer/' + repo.trim() + '/source/' + id;
    window.open(uri, '_blank');
  });

  $('.pe-button-close').on('click', function() {
    $(this).parent().css('display', 'none');
  });

  $('.pe-button-detail').on('click', function() {
    $(this).parent().css('display', 'none');
    var module = $('#pe-critic-module-name').text();
    var uri = '/explorer/critic/' + module + '?display=1';
    window.open(uri, '_blank');
    
  });
                     
  // ###################################################################
  // hamburger menu
  // ###################################################################
  $('#side-menu li').on('mouseout', function () {
    $('#hb label').toggle();
    $('#hb-menu').toggle();
  });
  
  $('#cb').on('click', function() {
    $('#hb-menu').toggle();
    $('#hb label').toggle();
  });
  
  $('.menu li').on('click', function () {
    var item = $(this).text().toLowerCase().split(' ')[0];
    
    var module = $('.selected-module');

    var uri = '/explorer/' + item + '/' + module.text();

    clear_context();

    if ( item == 'pod' && ! module.hasClass('pod') ) {
      add_pod(uri, module);
    }
    else if ( item == 'critic' )  {

      if ( $(this).text().indexOf('Detail') > -1) {
        uri = uri + '?display=1';
        window.open(uri, '_blank');
        return;
      }
      
      critique(uri);
      
      return;
    }
    else {
      window.open(uri, '_blank');
    }
  });
    
  $('#context').on('mouseleave', function() {
    clear_context();
  });
  
  $('.dir').on('click', function() {
    toggle_children($(this)); // $(this).next().toggle();
   $(this).children('i').each(function() { $(this).toggle(); });
  });

  // ###################################################################
  // Markdown
  // ###################################################################
  $('#pe-markdown-iframe').on('load', function() {
    $('#pe-markdown-iframe').css('display', 'block');
  });
  
  $('#pe-markdown-container button').on('click', function() {
    var id = $('#pe-markdown-select').val();
    var repo = $('title').text().trim();
    $('#pe-markdown-iframe').attr('src','/explorer/' + repo + '/markdown/' + id);
  });

  $('html').on('click', function() {
    if ( $('#pe-markdown-iframe').css('display') == 'block') {
      $('#pe-markdown-iframe').css('display', 'none');
    }
  });
  
  // ###################################################################
  // context menu
  // ###################################################################
  $('.module').on('contextmenu', function(e) {
    clear_context();
    
    var offset = $(this).offset();
    
    $(this).css("opacity", .5);
    $(this).addClass('selected-module');
    
    $('#context').css({ 
      position: "absolute",
      marginLeft: 0,
      marginTop: 0,
      top:  offset.top + $(this).height(),
      left: offset.left + 10 , // + $(this).width(),
      "z-index": 9999
    }).appendTo('body');
    
    $('#context').css('display', 'inline-block');

  });
  
});

// ########################################################################
function add_pod(uri, module) {
// ########################################################################
  
  if ( confirm('No POD in this module. Add POD?') != true ) {
    return false;
  }
      
  uri = uri + '?add=1';
  
  $.ajax({
    url : uri,
    dataType: 'json'
  }).done(function (data) {
    module.addClass('pod');
    
    display_success_message('Successfully added pod for ' + data.module);

    console.log(data);
    
  }).fail(function ($xhr, status, error) {
    var data = $xhr.responseJSON;
    
    console.log($xhr, status, error);
    
    display_error_message(data.error);
    
  }).always(function() {
  });
  
}

// ########################################################################
function critique(uri) {
// ########################################################################

  $('body').addClass('loading');
  
  $.ajax({
    url : uri,
    dataType: 'json'
  }).done(function (data) {

    $('body').removeClass('loading');

    console.log(data);

//  subs           => $stats->subs(),
//  statements     => $stats->statements(),
//  lines_of_perl  => $stats->lines_of_perl(),
//  violations     => $stats->violations_by_severity(),
//  policies       => $stats->violations_by_policy(),
//  total          => $stats->total_violations(),
//  avg_complexity => $stats->average_sub_mccabe(),

    var dependencies = data.summary.dependency_listing.modules;
    var dependencies_has_pod = data.summary.dependency_listing.has_pod;
    
    var has_pod = data.summary.has_pod ? 'YES' : 'NO';

    var complexity = data.summary.avg_complexity;
    
    var is_tidy = data.summary.is_tidy ? 'YES' : 'NO';
    
    $('#pe-critic-module-name').text(data.module);

    var rows = $('#pe-critic-summary-detail-table > tbody > tr');
    $(rows).children().each(function () { $(this).remove(); });

    var elem;
    
    append_to_table(rows, data.summary.lines_of_perl);
    append_to_table(rows, dependencies.length);
    append_to_table(rows, data.summary.subs);
    
    elem = append_to_table(rows, has_pod);
    
    if ( has_pod == 'NO' ) {
      $(elem).children().last().addClass('pe-critic-summary-alert');
    }
    
    elem = append_to_table(rows, is_tidy);

    if ( is_tidy == 'NO' ) {
      $(elem).children().last().addClass('pe-critic-summary-alert');
    }
    
    append_to_table(rows, data.summary.total);

    elem = append_to_table(rows, data.summary.avg_complexity);
    
    if ( complexity > 4 && complexity < 6)  {
      $(elem).children().last().addClass('pe-critic-summary-warning');
    }
    else if ( complexity > 6 ) {
      $(elem).children().last().addClass('pe-critic-summary-alert');
    }
         
        
    $('#pe-critic-module-violations span').each(function(index, severity) {
      $(severity).text('Severity ' + (index + 1) + ' (' + data.summary.violations[index + 1] + ')');
    });
    

    $('#pe-critic-module-dependency-list > li').each(function () {
      $(this).remove();
    });

    dependencies.forEach( (dep) => {
      var has_pod = dependencies_has_pod[dep];
      var pod_class = ' pe-has-pod';
      
      if ( typeof has_pod != 'undefined' ) {
        if ( has_pod == 0 ) {
          pod_class = '';
        }
      }
                                           
      var li = '<li class="pe-critic-dependency-item' + pod_class + '" >' + dep + '</li>';
      $('#pe-critic-module-dependency-list').append(li);
    });

    $('.pe-critic-dependency-item.pe-has-pod').on('click', function () {
      var item = $(this).text();
      
      var uri = '/explorer/pod/' + item;
      window.open(uri, '_blank');
    });
    
    $('#pe-critic-summary').css('display', 'block');

  }).fail(function ($xhr, status, error) {
    var data = $xhr.responseJSON;

    $('body').removeClass('loading');
    
    console.log($xhr, status, error);
          
    $('.error').css('display', 'inline-flex');
    
    $('#error-message').text(data.error);
    
  }).always(function() {
  });
}

// ########################################################################
function append_to_table (tr, text) {
// ########################################################################
  return $(tr).append('<td>' + text + '</td>');
}


// ########################################################################
function toggle_children (node) {
// ########################################################################
  var divs = $(node).siblings('div');

  for (i=0; i<divs.length; i++ ) {
    $(divs[i]).first().toggle();
  }
 
}

// ########################################################################
function clear_context() {
// ########################################################################
  
  var selected_module = $('.selected-module');

  $('#context').hide();
  
  if ( selected_module ) {
    $(selected_module).css('opacity', 1);
    $(selected_module).removeClass('selected-module');
  }
}

