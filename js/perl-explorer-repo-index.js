// ########################################################################
// (c) Copyright 2024, TBC Development Group, LLC
// All rights reserved.
// ########################################################################

// ########################################################################
$(document).ready(function () {
// ########################################################################
                     
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

  $('#pe-button-explore').on('click', function() {
    var repo = $('#pe-repo-listing').val();
    
    window.open('/explorer/' + repo, '_blank');
  });
  
});


