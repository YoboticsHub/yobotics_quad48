(function () {
  var languages = [
    { locale: "en", label: "English", title: "Switch to English", prefix: "" },
    { locale: "zh", label: "中文", title: "切换到中文", prefix: "zh/" },
    { locale: "ru", label: "Русский", title: "Переключиться на русский", prefix: "ru/" },
  ];

  function stripLanguage(inputPath) {
    return (inputPath || "").replace(/^(zh|en|ru)\//, "");
  }

  function htmlPathFromInput(inputPath) {
    var path = stripLanguage(inputPath);
    if (!path) {
      return "index.html";
    }
    return path.replace(/\.md$/, ".html");
  }

  function outputPath(locale, htmlPath) {
    var language = languages.filter(function (item) {
      return item.locale === locale;
    })[0];
    return (language ? language.prefix : "") + htmlPath;
  }

  function relativePath(fromFile, toFile) {
    var fromParts = fromFile.split("/").slice(0, -1).filter(Boolean);
    var toParts = toFile.split("/").filter(Boolean);
    var common = 0;

    while (
      common < fromParts.length &&
      common < toParts.length &&
      fromParts[common] === toParts[common]
    ) {
      common += 1;
    }

    var up = fromParts.slice(common).map(function () {
      return "..";
    });
    var down = toParts.slice(common);
    var result = up.concat(down).join("/");
    return result || "index.html";
  }

  function languageState() {
    var inputPath = window.mkdocs_page_input_path || "";
    var locale = "en";

    languages.forEach(function (language) {
      if (inputPath.indexOf(language.prefix) === 0 && language.prefix) {
        locale = language.locale;
      }
    });

    if (!inputPath) {
      languages.forEach(function (language) {
        if (language.prefix && window.location.pathname.indexOf("/" + language.prefix) !== -1) {
          locale = language.locale;
        }
      });
    }

    return {
      locale: locale,
      htmlPath: htmlPathFromInput(inputPath),
    };
  }

  function insertSwitcher() {
    var state = languageState();
    var fromFile = outputPath(state.locale, state.htmlPath);
    var search = document.querySelector(".wy-side-nav-search");

    if (!search || search.querySelector(".language-switcher")) {
      return;
    }

    var wrapper = document.createElement("div");
    wrapper.className = "language-switcher";

    languages
      .filter(function (language) {
        return language.locale !== state.locale;
      })
      .forEach(function (language, index) {
        var link = document.createElement("a");
        link.className = "language-switcher__link";
        link.href = relativePath(fromFile, outputPath(language.locale, state.htmlPath));
        link.textContent = language.label;
        link.setAttribute("aria-label", language.title);
        link.setAttribute("title", language.title);

        if (index > 0) {
          wrapper.appendChild(document.createTextNode(" | "));
        }

        wrapper.appendChild(link);
      });

    search.appendChild(wrapper);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", insertSwitcher);
  } else {
    insertSwitcher();
  }
})();
