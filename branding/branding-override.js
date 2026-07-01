// Sysplore OpenVAS Docker - Branding Override
// This script modifies the GSA login page to credit Sysplore
(function() {
  'use strict';

  const SYSPLORE_BRANDING = "Sysplore";
  const SYSPLORE_URL = "https://sysplore.github.io/openvas-docker/";

  function applyBranding() {
    // Override footer copyright text
    var footers = document.querySelectorAll('footer');
    footers.forEach(function(footer) {
      var text = footer.textContent || '';
      if (text.indexOf('Greenbone') !== -1) {
        footer.innerHTML = 'Copyright &copy; 2025-' + new Date().getFullYear() +
          ' by <a href="' + SYSPLORE_URL + '" target="_blank" rel="noopener noreferrer" style="color:#888;font-size:10px;">' +
          SYSPLORE_BRANDING + '</a>. Powered by Greenbone Community Edition.';
      }
    });

    // Add Sysplore credit banner to the login form
    var loginForm = document.querySelector('[data-testid="login-wrapper"]') ||
                    document.querySelector('.login-wrapper') ||
                    document.querySelector('form');
    if (loginForm && !document.getElementById('sysplore-credit')) {
      var credit = document.createElement('div');
      credit.id = 'sysplore-credit';
      credit.style.cssText = 'text-align:center;font-size:10px;color:#999;margin-top:15px;padding-top:10px;border-top:1px solid #eee;';
      credit.innerHTML = 'Container maintained by <a href="' + SYSPLORE_URL +
        '" target="_blank" style="color:#4caf50;text-decoration:none;">' +
        SYSPLORE_BRANDING + '</a>';
      loginForm.parentNode.insertBefore(credit, loginForm.nextSibling);
    }
  }

  // Apply on load
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', applyBranding);
  } else {
    applyBranding();
  }

  // Also wait for React to finish rendering
  setTimeout(applyBranding, 1000);
  setTimeout(applyBranding, 3000);
})();
