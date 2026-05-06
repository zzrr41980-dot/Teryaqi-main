(function () {
  const currentPath = window.location.pathname;
  const directoryPath = currentPath.substring(0, currentPath.lastIndexOf('/'));
  window.TERYAQI_API_BASE = window.location.origin + directoryPath;
})();