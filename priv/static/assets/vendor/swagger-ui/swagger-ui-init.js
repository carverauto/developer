/* Initialize Swagger UI from #swagger-ui[data-openapi-url]. */
(function () {
  var el = document.getElementById("swagger-ui");
  if (!el || typeof window.SwaggerUIBundle === "undefined") return;
  if (el.dataset.rendered === "true") return;
  el.dataset.rendered = "true";
  window.SwaggerUIBundle({
    url: el.getAttribute("data-openapi-url"),
    dom_id: "#swagger-ui",
    deepLinking: true,
    validatorUrl: null,
    tryItOutEnabled: true,
    presets: [SwaggerUIBundle.presets.apis],
    layout: "BaseLayout"
  });
})();
