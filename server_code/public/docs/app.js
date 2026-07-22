const searchInput = document.getElementById("docSearch");
const searchableSections = Array.from(document.querySelectorAll("[data-searchable]"));
const mobileMenuButton = document.getElementById("mobileMenuButton");
const mobileMenu = document.getElementById("mobileMenu");
const tocLinks = Array.from(document.querySelectorAll(".toc-link"));

if (searchInput) {
  searchInput.addEventListener("input", () => {
    const query = searchInput.value.trim().toLowerCase();

    searchableSections.forEach((section) => {
      const text = section.textContent.toLowerCase();
      const matches = !query || text.includes(query);
      section.classList.toggle("is-hidden", !matches);
    });
  });
}

if (mobileMenuButton && mobileMenu) {
  mobileMenuButton.addEventListener("click", () => {
    mobileMenu.classList.toggle("hidden");
  });

  mobileMenu.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", () => {
      mobileMenu.classList.add("hidden");
    });
  });
}

const sectionMap = tocLinks
  .map((link) => {
    const id = link.getAttribute("href")?.slice(1);
    if (!id) return null;
    const section = document.getElementById(id);
    if (!section) return null;
    return { link, section };
  })
  .filter(Boolean);

const activateCurrentSection = () => {
  const offset = 180;
  let activeId = "";

  sectionMap.forEach(({ section }) => {
    const top = section.getBoundingClientRect().top;
    if (top - offset <= 0) {
      activeId = section.id;
    }
  });

  tocLinks.forEach((link) => {
    const isActive = link.getAttribute("href") === `#${activeId}`;
    link.classList.toggle("is-active", isActive);
  });
};

document.addEventListener("scroll", activateCurrentSection, { passive: true });
window.addEventListener("load", activateCurrentSection);
