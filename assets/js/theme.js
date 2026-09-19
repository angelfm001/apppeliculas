// Tema oscuro/claro + navbar responsive (extraido de final.php)
(function () {
  function initTheme() {
    var toggle = document.getElementById('themeToggle');
    if (!toggle) return;
    toggle.addEventListener('change', function () {
      var html = document.documentElement;
      var navbar = document.getElementById('navbar');
      var lbl = document.getElementById('lbl1');
      if (this.checked) {
        html.setAttribute('data-bs-theme', 'dark');
        if (lbl) lbl.textContent = 'Desactivar';
        if (navbar) { navbar.classList.remove('navbar-light', 'bg-light'); navbar.classList.add('navbar-dark', 'bg-dark'); }
      } else {
        html.setAttribute('data-bs-theme', 'light');
        if (lbl) lbl.textContent = 'Activar';
        if (navbar) { navbar.classList.remove('navbar-dark', 'bg-dark'); navbar.classList.add('navbar-light', 'bg-light'); }
      }
    });
  }
  function adjustNavbar() {
    var navbar = document.getElementById('navbar');
    if (!navbar) return;
    if (window.innerWidth < 817) {
      navbar.classList.remove('navbar-expand');
      navbar.classList.add('navbar-no-expand');
    } else {
      navbar.classList.add('navbar-expand');
      navbar.classList.remove('navbar-no-expand');
    }
  }
  window.addEventListener('resize', adjustNavbar);
  document.addEventListener('DOMContentLoaded', function () { initTheme(); adjustNavbar(); });
})();
