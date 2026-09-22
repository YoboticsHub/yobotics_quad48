(function () {
  var COPY_LABEL = "复制";
  var COPIED_LABEL = "已复制";
  var RESET_MS = 1600;

  function copyWithTextarea(text) {
    return new Promise(function (resolve, reject) {
      var textarea = document.createElement("textarea");
      textarea.value = text;
      textarea.setAttribute("readonly", "");
      textarea.style.position = "fixed";
      textarea.style.left = "-9999px";
      document.body.appendChild(textarea);
      textarea.select();
      try {
        document.execCommand("copy") ? resolve() : reject(new Error("copy failed"));
      } catch (error) {
        reject(error);
      } finally {
        document.body.removeChild(textarea);
      }
    });
  }

  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text).catch(function () {
        return copyWithTextarea(text);
      });
    }
    return copyWithTextarea(text);
  }

  function codeText(pre) {
    var code = pre.querySelector("code");
    var text = (code || pre).innerText || "";
    return text.replace(/\n$/, "");
  }

  function addCopyButton(pre) {
    if (pre.parentElement && pre.parentElement.classList.contains("code-copy-wrapper")) {
      return;
    }

    var wrapper = document.createElement("div");
    wrapper.className = "code-copy-wrapper";
    pre.parentNode.insertBefore(wrapper, pre);
    wrapper.appendChild(pre);

    var button = document.createElement("button");
    button.type = "button";
    button.className = "code-copy-btn";
    button.setAttribute("aria-label", COPY_LABEL);
    button.textContent = COPY_LABEL;

    button.addEventListener("click", function () {
      copyText(codeText(pre)).then(function () {
        button.classList.add("copied");
        button.textContent = COPIED_LABEL;
        window.setTimeout(function () {
          button.classList.remove("copied");
          button.textContent = COPY_LABEL;
        }, RESET_MS);
      });
    });

    wrapper.appendChild(button);
  }

  function initCopyButtons() {
    document.querySelectorAll(".rst-content pre").forEach(addCopyButton);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initCopyButtons);
  } else {
    initCopyButtons();
  }
})();
