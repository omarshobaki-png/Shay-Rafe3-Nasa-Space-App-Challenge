/* Shay Rafe3: a viewport-sized, keyboard-accessible mission presentation. */

// Where the GET THE GAME dialog's play button goes: the web build in play/, next to this page.
// While it is empty, the dialog says the browser version is coming soon.
const PLAY_URL = "play/";
const DATA_PDF_URL = "NASA_Data_In_Game.pdf";
const GAME_REPO_URL = "https://github.com/omarshobaki-png/Shay-Rafe3-Nasa-Space-App-Challenge";

const SECTIONS = ["overview", "project", "missions", "lab", "data", "team"];
const SECTION_NAMES = [
  "OVERVIEW",
  "THE GAME",
  "MISSIONS",
  "MISSION LAB",
  "NASA DATA",
  "OUR TEAM",
];
const el = (id) => document.getElementById(id);
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
let activeSection = "";
function reveal(node, distance = 16) {
  if (!node || reducedMotion.matches || !node.animate) return;
  node.getAnimations().forEach((animation) => animation.cancel());
  node.animate(
    [
      {
        opacity: 0,
        transform: `translateY(${distance}px)`,
        filter: "blur(3px)",
      },
      { opacity: 1, transform: "translateY(0)", filter: "blur(0)" },
    ],
    { duration: 440, easing: "cubic-bezier(.2,.8,.2,1)" },
  );
}
function navigate(section, updateHistory = true) {
  if (!SECTIONS.includes(section)) section = "overview";
  if (activeSection === section) return;
  const previous = activeSection;
  activeSection = section;
  document.querySelectorAll(".view").forEach((view) => {
    view.hidden = view.id !== section;
  });
  document.querySelectorAll("[data-section]").forEach((link) => {
    if (link.dataset.section === section)
      link.setAttribute("aria-current", "page");
    else link.removeAttribute("aria-current");
  });
  const index = SECTIONS.indexOf(section);
  el("section-status").textContent =
    `${String(index + 1).padStart(2, "0")} / ${SECTION_NAMES[index]}`;
  if (updateHistory) history.pushState({ section }, "", `#${section}`);
  reveal(el(section), 24);
  if (previous && !reducedMotion.matches)
    document.querySelectorAll(".transition-lines i").forEach((line, i) => {
      if (line.animate) {
        line.getAnimations().forEach((animation) => animation.cancel());
        line.animate(
          [{ transform: "translateX(0)" }, { transform: "translateX(205%)" }],
          { duration: 600, delay: i * 55, easing: "cubic-bezier(.3,0,.2,1)" },
        );
      }
    });
}
document.addEventListener("click", (event) => {
  const link = event.target.closest('a[href^="#"]');
  if (link && SECTIONS.includes(link.hash.slice(1))) {
    event.preventDefault();
    navigate(link.hash.slice(1));
  }
  const control = event.target.closest("button");
  if (control && !reducedMotion.matches) {
    const rect = control.getBoundingClientRect();
    const ripple = document.createElement("span");
    ripple.className = "ripple";
    ripple.setAttribute("aria-hidden", "true");
    ripple.style.left = `${event.detail ? event.clientX - rect.left : rect.width / 2}px`;
    ripple.style.top = `${event.detail ? event.clientY - rect.top : rect.height / 2}px`;
    control.appendChild(ripple);
    ripple.addEventListener("animationend", () => ripple.remove(), {
      once: true,
    });
    setTimeout(() => ripple.remove(), 800);
  }
});
function stepSection(step) {
  navigate(
    SECTIONS[
      (SECTIONS.indexOf(activeSection) + step + SECTIONS.length) %
        SECTIONS.length
    ],
  );
}
el("previous-section").addEventListener("click", () => stepSection(-1));
el("next-section").addEventListener("click", () => stepSection(1));
document.querySelector(".section-nav").addEventListener("keydown", (event) => {
  if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return;
  event.preventDefault();
  let index = SECTIONS.indexOf(activeSection);
  index =
    event.key === "Home"
      ? 0
      : event.key === "End"
        ? SECTIONS.length - 1
        : (index + (event.key === "ArrowRight" ? 1 : -1) + SECTIONS.length) %
          SECTIONS.length;
  navigate(SECTIONS[index]);
  document.querySelector(`[data-section="${SECTIONS[index]}"]`).focus();
});
window.addEventListener("popstate", () =>
  navigate(location.hash.slice(1), false),
);
window.addEventListener("hashchange", () => {
  if (location.hash !== "#main") navigate(location.hash.slice(1), false);
});

function wireTabs(selector, key, render) {
  const tabs = [...document.querySelectorAll(selector)];
  function select(tab, focus = false) {
    tabs.forEach((t) => {
      const selected = t === tab;
      t.setAttribute("aria-selected", String(selected));
      t.tabIndex = selected ? 0 : -1;
    });
    el(tab.getAttribute("aria-controls")).setAttribute(
      "aria-labelledby",
      tab.id,
    );
    render(tab.dataset[key]);
    if (focus) tab.focus();
  }
  tabs.forEach((tab, index) => {
    tab.addEventListener("click", () => select(tab));
    tab.addEventListener("keydown", (event) => {
      if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key))
        return;
      event.preventDefault();
      const next =
        event.key === "Home"
          ? 0
          : event.key === "End"
            ? tabs.length - 1
            : (index + (event.key === "ArrowRight" ? 1 : -1) + tabs.length) %
              tabs.length;
      select(tabs[next], true);
    });
  });
}
const STAGES = {
  build: {
    image: "builder_mars",
    alt: "Spacecraft assembly hangar with parts and Mission Control system checks",
    caption: "01 / SPACECRAFT ASSEMBLY",
    title: "Every part is a decision.",
    copy: "Snap parts onto your ship. Mission Control lights one lamp per system and tells you in plain words what’s wrong.",
  },
  fly: {
    image: "cruise_event_mars",
    alt: "A decision event on the way to Mars: two teams used different units",
    caption: "02 / LAUNCH, CRUISE, ARRIVAL",
    title: "Then the universe gets a vote.",
    copy: "Launch, cruise, and arrive. Real 2024 solar storms from NASA’s records and decisions based on real missions hit your ship on the way. Your design determines how well it copes.",
  },
  learn: {
    image: "report_moon",
    alt: "Moon mission report with goals, four scores, the lesson, and a real-mission comparison",
    caption: "03 / THE MISSION REPORT",
    title: "Don’t just fail. Find out why.",
    copy: "The report traces each result back to a decision and compares your ship with a real mission. Redesign, try again, and bring more science home.",
  },
};
wireTabs("[data-stage]", "stage", (key) => {
  const stage = STAGES[key];
  el("stage-image").src = `assets/${stage.image}.png`;
  el("stage-image").alt = stage.alt;
  ["caption", "title", "copy"].forEach((field) => {
    el(`stage-${field}`).textContent = stage[field];
  });
  reveal(el("stage-content"));
});
const ROLE_DETAILS = {
  build:
    "Pick a rocket and flight path, then fill the bays: power, radio, instruments, landing gear, rovers and fuel. Each lamp turns green only with NASA's margin.",
  launch:
    "Lift off, throttle back through max-Q, drop the empty stage and reach orbit at 7.8 km/s. Too heavy for the rocket, and you never get there.",
  cruise:
    "Months or years pass on a real flight path. Solar storms from NASA's records and decisions based on real missions hit the ship on the way.",
  explore:
    "Hold the entry corridor, brake and land in real gravity, then drive the rover to drill rocks and take photos, or fly a drone through the giant planets' rings.",
};
document.querySelectorAll("[data-role]").forEach((button) =>
  button.addEventListener("click", () => {
    document
      .querySelectorAll("[data-role]")
      .forEach((b) => b.setAttribute("aria-pressed", String(b === button)));
    el("role-detail").textContent = ROLE_DETAILS[button.dataset.role];
    reveal(el("role-detail"), 8);
  }),
);
const MISSIONS = {
  mercury: {
    image: "surface_mercury",
    alt: "A rover on Mercury under a huge, close Sun",
    caption: "MERCURY SURFACE OPERATIONS",
    lesson: "THE LESSON / HEAT AND BRAKING",
    title: "Land next to the Sun. Survey its rocks.",
    copy: "Sunlight is 6.7 times Earth’s, so the ship needs a sunshade. With no air, all 3 km/s of the landing comes from fuel—and the cheap path takes 6.6 years.",
    facts: [
      ["GRAVITY", "3.70 m/s²"],
      ["SUNLIGHT", "6.7× Earth’s"],
      ["RADIO DELAY", "4 to 12 minutes"],
      ["REAL MISSION", "MESSENGER · 2011–2015"],
    ],
  },
  venus: {
    image: "landing_venus",
    alt: "A lander sinks through Venus’ thick air toward a rock slab",
    caption: "VENUS DESCENT",
    lesson: "THE LESSON / PRESSURE AND TIME",
    title: "Land in crushing air. Work fast.",
    copy: "The air presses like 900 m of ocean and does all the braking—if the lander has a heat shield and a pressure hull. Then batteries and radio get 127 minutes.",
    facts: [
      ["GRAVITY", "8.87 m/s²"],
      ["TIME ON THE SURFACE", "127 minutes"],
      ["RADIO DELAY", "2 to 14 minutes"],
      ["REAL MISSION", "Venera 13 · 1982"],
    ],
  },
  moon: {
    image: "surface_moon",
    alt: "A rover drives across the Moon beside the lander",
    caption: "LUNAR SURFACE OPERATIONS",
    lesson: "THE LESSON / FUEL VERSUS MASS",
    title: "Land. Collect three samples. Fly home.",
    copy: "There’s no air to slow you down. Every metre per second of braking comes from fuel—and that fuel has to carry itself.",
    facts: [
      ["GRAVITY", "1.62 m/s²"],
      ["RADIO DELAY", "1.3 seconds"],
      ["TASKS", "Photos · samples · crew"],
      ["REAL MISSIONS", "CAPSTONE · Apollo 11"],
    ],
  },
  mars: {
    image: "entry_mars",
    alt: "The lander enters Mars’ atmosphere and must hold the entry corridor",
    caption: "MARS ENTRY & LANDING",
    lesson: "THE LESSON / AIR AND DISTANCE",
    title: "Land a rover. Drill four rocks. Send the data.",
    copy: "Mars’ thin air demands a heat shield. With radio delays of up to 22 minutes, the lander needs to handle landing without instant instructions from Earth.",
    facts: [
      ["GRAVITY", "3.71 m/s²"],
      ["SUNLIGHT", "43% of Earth’s"],
      ["TASKS", "Photos · rocks · crew"],
      ["REAL MISSION", "Perseverance · 2021"],
    ],
  },
  jupiter: {
    image: "drone_jupiter",
    alt: "A drone photographs a marked spot in Jupiter’s faint rings",
    caption: "JUPITER RING DRONE OPERATIONS",
    lesson: "THE LESSON / RADIATION AND POWER",
    title: "Orbit inside the radiation belts. Fly the drone.",
    copy: "Jupiter’s belts fry unshielded electronics, and sunlight is under 4% of Earth’s: carry nuclear power, or huge solar wings like Juno.",
    facts: [
      ["SUNLIGHT", "3.7% of Earth’s"],
      ["RADIO DELAY", "33 to 54 minutes"],
      ["TASKS", "Ring photos · ring grains"],
      ["REAL MISSION", "Juno · 2016–"],
    ],
  },
  saturn: {
    image: "drone_saturn",
    alt: "A drone flying through Saturn’s rings to collect ice",
    caption: "SATURN RING DRONE OPERATIONS",
    lesson: "THE LESSON / POWER AND DATA",
    title: "Reach orbit. Send a drone through the rings.",
    copy: "Sunlight is about 1% of Earth’s. In the game, players discover nuclear power while balancing a distant radio link, collecting ice, and docking the drone.",
    facts: [
      ["SUNLIGHT", "14.8 W/m²"],
      ["RADIO DELAY", "About 80 minutes"],
      ["TASKS", "Ring photos · ring grains"],
      ["REAL MISSION", "Cassini · 1997–2017"],
    ],
  },
  uranus: {
    image: "builder_uranus",
    alt: "Building a ship for Uranus: the guide points to nuclear power because sunlight is 0.27% of Earth’s",
    caption: "URANUS SPACECRAFT ASSEMBLY",
    lesson: "THE LESSON / DISTANCE",
    title: "Be the first to orbit Uranus.",
    copy: "Thirteen years of cruise, sunlight at 0.3% of Earth’s and a radio link 370 times slower than at Earth: power, data and money all run short.",
    facts: [
      ["SUNLIGHT", "0.3% of Earth’s"],
      ["RADIO DELAY", "2.4 to 2.9 hours"],
      ["TASKS", "Ring photos · ring grains"],
      ["REAL MISSION", "Voyager 2 flyby · 1986"],
    ],
  },
  neptune: {
    image: "drone_neptune",
    alt: "A drone flies to a marked spot near Neptune’s moons",
    caption: "NEPTUNE RING DRONE OPERATIONS",
    lesson: "THE LESSON / THE LONG WAY",
    title: "The farthest world. Brake hard, or arrive slowly.",
    copy: "After 12 years the ship must brake hard into orbit, or fly 16 years and let its nuclear power fade. Its radio link is the slowest in the game.",
    facts: [
      ["SUNLIGHT", "0.1% of Earth’s"],
      ["RADIO DELAY", "About 4 hours"],
      ["TASKS", "Ring photos · ring grains"],
      ["REAL MISSION", "Voyager 2 flyby · 1989"],
    ],
  },
};
function definitionList(node, pairs) {
  node.replaceChildren(
    ...pairs.map(([label, value]) => {
      const row = document.createElement("div"),
        dt = document.createElement("dt"),
        dd = document.createElement("dd");
      dt.textContent = label;
      dd.textContent = value;
      row.append(dt, dd);
      return row;
    }),
  );
}
wireTabs("[data-mission]", "mission", (key) => {
  const mission = MISSIONS[key];
  el("mission-image").src = `assets/${mission.image}.png`;
  el("mission-image").alt = mission.alt;
  ["caption", "lesson", "title", "copy"].forEach((field) => {
    el(`mission-${field}`).textContent = mission[field];
  });
  definitionList(el("mission-facts"), mission.facts);
  reveal(el("mission-content"));
});
const VE = (300 * 9.81) / 1000;
const DEST = {
  mercury: {
    dv: 3.89,
    cap: 9000,
    rocket: "Falcon Heavy",
    note: "Mercury: 0.86 km/s into orbit + 3.0 km/s to land, with no air to help. The hardest landing in the game.",
  },
  venus: {
    dv: 0.03,
    cap: 4020,
    rocket: "Falcon 9",
    note: "Venus: the thick air does all the braking. Only 0.03 km/s of course corrections needs fuel; the challenge is surviving 127 minutes.",
  },
  moon: {
    dv: 2.93,
    cap: 4020,
    rocket: "Falcon 9",
    note: "Moon: 0.90 km/s into orbit + 2.0 km/s to land + 0.03 km/s of course corrections. No air, so it’s all fuel.",
  },
  mars: {
    dv: 0.33,
    cap: 4020,
    rocket: "Falcon 9",
    note: "Mars: the heat shield and parachute do most of the braking. 0.30 km/s is left for the landing burn.",
  },
  jupiter: {
    dv: 0.57,
    cap: 6000,
    rocket: "Falcon Heavy",
    note: "Jupiter: 0.54 km/s to brake into orbit. The hard part is radiation and power, not fuel.",
  },
  saturn: {
    dv: 0.66,
    cap: 6000,
    rocket: "Falcon Heavy",
    note: "Saturn: 0.63 km/s to brake into orbit. The hard trade-off here is power, not fuel.",
  },
  uranus: {
    dv: 1.12,
    cap: 5000,
    rocket: "Falcon Heavy",
    note: "Uranus: 1.09 km/s to brake into orbit after 13 years. Power and radio are the real limits.",
  },
  neptune: {
    dv: 2.53,
    cap: 3600,
    rocket: "Falcon Heavy",
    note: "Neptune: 2.5 km/s to brake into orbit after 12 years: the biggest orbit burn in the game.",
  },
};
function calculateMission(destination, dryMass) {
  const d = DEST[destination],
    fuel = dryMass * (Math.exp(d.dv / VE) - 1),
    total = dryMass + fuel;
  const spare = (d.cap - total) / d.cap;
  return {
    ...d,
    fuel,
    total,
    spare,
    state: spare < 0 ? "nogo" : spare < 0.35 ? "caution" : "go",
  };
}
const fmt = (number) => Math.round(number).toLocaleString("en-US");
function updateConsole() {
  const mass = Number(el("dry").value);
  const result = calculateMission(
    document.querySelector('input[name="dest"]:checked').value,
    mass,
  );
  el("dry-out").textContent = `${fmt(mass)} kg`;
  el("r-dv").textContent = `${result.dv.toFixed(2)} km/s`;
  el("r-fuel").textContent = `${fmt(result.fuel)} kg`;
  el("r-total").textContent = `${fmt(result.total)} kg`;
  el("r-cap").textContent = `${fmt(result.cap)} kg`;
  el("dest-note").textContent = result.note;
  const scale = Math.max(result.total, result.cap) * 1.08;
  el("bar-dry").style.width = `${(mass / scale) * 100}%`;
  el("bar-fuel").style.width = `${(result.fuel / scale) * 100}%`;
  el("cap-line").style.left = `${(result.cap / scale) * 100}%`;
  el("status").dataset.state = result.state;
  el("status-text").textContent =
    result.state === "nogo"
      ? `NO-GO. ${fmt(result.total - result.cap)} kg over ${result.rocket} capacity.`
      : result.state === "caution"
        ? `CAUTION. ${Math.round(result.spare * 100)}% spare; below the demo’s 35% target.`
        : `GO. ${Math.round(result.spare * 100)}% spare capacity.`;
}
el("dry").addEventListener("input", updateConsole);
document.querySelectorAll('input[name="dest"]').forEach((radio) =>
  radio.addEventListener("change", () => {
    updateConsole();
    reveal(el("status"), 6);
  }),
);

const SCIENCE = [
  {
    name: "Space weather",
    type: "DONKI / EVENT DATA",
    value: "Real 2024 geomagnetic storms. Up to Kp 9 on 10 May 2024.",
    effect:
      "Storms hit the spacecraft during cruise. In the game, unshielded instruments can break—so resilience is a design decision.",
    source: "NASA DONKI",
    url: "https://kauai.ccmc.gsfc.nasa.gov/DONKI/",
  },
  {
    name: "Planetary physics",
    type: "WORLD / PHYSICAL DATA",
    value: "Gravity, sunlight, and distance for each destination.",
    effect:
      "These values shape landing physics, jump height, radio delays, and the power your solar panels produce.",
    source: "NASA Planetary Fact Sheets",
    url: "https://nssdc.gsfc.nasa.gov/planetary/factsheet/",
  },
  {
    name: "Design margins",
    type: "JPL / DESIGN GUIDANCE",
    value: "35% spare mass and power at the concept stage.",
    effect:
      "The game turns design margins into GO / NO-GO review checks. The lab on this site uses a simplified 35% spare-capacity threshold.",
    source: "JPL · Concept Maturity Levels (2013)",
  },
  {
    name: "Rocket efficiency",
    type: "GMAT / MODEL PARAMETERS",
    value:
      "300 s engine specific impulse. 5% annual panel aging in the game model.",
    effect:
      "The rocket equation determines fuel use. Aging solar panels make long-trip power planning more demanding.",
    source: "NASA GMAT / project model",
    url: "https://github.com/nasa/GMAT",
  },
  {
    name: "Nuclear power",
    type: "MMRTG / HARDWARE DATA",
    value: "110 W electrical power. 45 kg mass.",
    effect:
      "The game’s MMRTG is the practical power choice for Saturn, where sunlight is about 1% of what Earth receives.",
    source: "NASA MMRTG fact sheet · documented in game data",
  },
  {
    name: "Spacecraft parts",
    type: "SMALLSAT / TECHNOLOGY",
    value:
      "Solar arrays, batteries, and radios with sourced performance figures.",
    effect:
      "Part mass and performance feed directly into the builder, so players see the costs of more power or better communications.",
    source: "NASA Small Spacecraft Technology report",
  },
  {
    name: "Science instruments",
    type: "MRO + CASSINI / PAYLOAD",
    value: "CTX, CRISM, and MAG instrument data.",
    effect:
      "Real mass, power requirements, and data generation give each instrument an engineering cost as well as a science purpose.",
    source: "NASA mission pages · NSSDCA",
    url: "https://nssdc.gsfc.nasa.gov/",
  },
  {
    name: "Mission heritage",
    type: "FLIGHT HISTORY / COMPARISONS",
    value: "Apollo 11. CAPSTONE. Perseverance. Cassini.",
    effect:
      "Real missions provide flight-time and path references, and the comparison shown in your final mission report.",
    source: "NASA mission pages",
    url: "https://science.nasa.gov/solar-system/",
  },
];
function selectScience(index, animate = true) {
  const item = SCIENCE[index];
  document
    .querySelectorAll("[data-science]")
    .forEach((b) =>
      b.setAttribute(
        "aria-pressed",
        String(Number(b.dataset.science) === index),
      ),
    );
  el("data-number").textContent =
    `${String(index + 1).padStart(2, "0")} / ${item.type}`;
  el("data-name").textContent = item.name;
  el("data-value").textContent = item.value;
  el("data-effect").textContent = item.effect;
  const source = item.url
    ? document.createElement("a")
    : document.createElement("span");
  source.textContent = `SOURCE / ${item.source}${item.url ? " ↗" : ""}`;
  if (item.url) {
    source.href = item.url;
    source.target = "_blank";
    source.rel = "noopener";
  }
  el("data-source").replaceChildren(source);
  if (animate) reveal(el("data-detail"));
}
SCIENCE.forEach((item, index) => {
  const button = document.createElement("button");
  button.dataset.science = index;
  button.setAttribute("aria-controls", "data-detail");
  const number = document.createElement("span"),
    name = document.createElement("b"),
    arrow = document.createElement("i");
  number.textContent = `DATA SYSTEM ${String(index + 1).padStart(2, "0")}`;
  name.textContent = item.name;
  arrow.textContent = "↗";
  arrow.setAttribute("aria-hidden", "true");
  button.append(number, name, arrow);
  button.addEventListener("click", () => selectScience(index));
  el("data-selector").append(button);
});
const TEAM = [
  {
    name: "Alameen Abu Fkheida",
    initials: "AF",
    role: "CREATIVE GAME DESIGN & LOGIC",
    copy: "Develops creative game design and gameplay logic, tests the game, and helps refine its visuals.",
    tags: ["Creative design", "Game logic", "Game QA", "Visual support"],
  },
  {
    name: "Omar Takhman",
    initials: "OT",
    role: "VIDEO TRAILER, DESIGN & RESEARCH",
    copy: "Creates the video trailer, contributes to game design and scientific research, and tests the game.",
    tags: ["Video trailer", "Game design", "Science research", "Game QA"],
  },
  {
    name: "Omar Shobaki",
    initials: "OS",
    role: "WEBSITE CONTENT, PRESENTATION & RESEARCH",
    copy: "Creates website content and presentation material, manages the GitHub repository, contributes scientific research, and tests the game.",
    tags: [
      "Website content",
      "Presentation",
      "GitHub management",
      "Science research",
      "Game QA",
    ],
  },
  {
    name: "Mohammad Humaidan",
    initials: "MH",
    role: "MOBILE INTEGRATION, PRESENTATION & RESEARCH",
    copy: "Works on mobile integration for the game, creates presentation material, contributes scientific research, and tests the game.",
    tags: ["Mobile integration", "Presentation", "Science research", "Game QA"],
  },
  {
    name: "Mahdi Al Sheikh",
    initials: "MS",
    role: "PRIMARY GAME DEVELOPER",
    copy: "Serves as the designated game developer, implements gameplay logic, and carries out QA testing.",
    tags: ["Game development", "Game logic", "QA testing"],
  },
  {
    name: "Ahmad Taweel",
    initials: "AT",
    role: "WEBSITE DESIGN, GAME LOGIC & PRODUCT PITCH",
    copy: "Designs the website and its UI, contributes gameplay logic and QA testing, develops video prompts and scripts, and creates the concept behind the product pitch.",
    tags: [
      "Website design & UI",
      "Game logic",
      "Game QA",
      "Video prompts & scripts",
      "Product pitch",
    ],
  },
];
let memberIndex = 0;
function selectMember(index, animate = true) {
  memberIndex = (index + TEAM.length) % TEAM.length;
  const member = TEAM[memberIndex];
  document
    .querySelectorAll("[data-member]")
    .forEach((b) =>
      b.setAttribute(
        "aria-pressed",
        String(Number(b.dataset.member) === memberIndex),
      ),
    );
  el("member-avatar").textContent = member.initials;
  el("member-number").textContent =
    `CREW ${String(memberIndex + 1).padStart(2, "0")} / 06`;
  el("member-name").textContent = member.name;
  el("member-role").textContent = member.role;
  el("member-copy").textContent = member.copy;
  el("member-tags").replaceChildren(
    ...member.tags.map((tag) => {
      const span = document.createElement("span");
      span.textContent = tag;
      return span;
    }),
  );
  if (animate) reveal(el("member-detail"));
}
TEAM.forEach((member, index) => {
  const button = document.createElement("button");
  button.dataset.member = index;
  button.setAttribute("aria-controls", "member-detail");
  const avatar = document.createElement("span"),
    copy = document.createElement("span"),
    name = document.createElement("span"),
    number = document.createElement("span");
  avatar.className = "crew-initials";
  avatar.textContent = member.initials;
  avatar.setAttribute("aria-hidden", "true");
  name.className = "crew-name";
  name.textContent = member.name;
  number.className = "crew-index";
  number.textContent = `CREW ${String(index + 1).padStart(2, "0")} / VIEW PROFILE`;
  copy.append(name, number);
  button.append(avatar, copy);
  button.addEventListener("click", () => selectMember(index));
  el("team-list").append(button);
});
el("member-prev").addEventListener("click", () =>
  selectMember(memberIndex - 1),
);
el("member-next").addEventListener("click", () =>
  selectMember(memberIndex + 1),
);
const dialog = el("info-dialog");
function openDialog(kind) {
  const contents =
    kind === "credits"
      ? `<p class="eyebrow">THE PEOPLE, TOOLS & SOURCES</p><h2 id="dialog-title">Behind the pixels.</h2><p>The game idea and design are the team’s own. As disclosed in the game repository, Claude helped write GDScript and the scripts that generate art and sound, with team review. No AI image generators were used for the game artwork.</p><p>Website design by Ahmad Taweel and the team; screenshots from the current game build. Pixel font: Press Start 2P, CodeMan38, SIL Open Font License.</p><p>Independent NASA Space Apps team project. Not affiliated with or endorsed by NASA.</p><div class="dialog-links"><a class="quiet-link" href="https://github.com/omarshobaki-png/Shay-Rafe3-Nasa-Space-App-Challenge" target="_blank" rel="noopener">Game sources ↗</a><a class="quiet-link" href="${DATA_PDF_URL}" target="_blank" rel="noopener">NASA data in the game (PDF) ↗</a><a class="quiet-link" href="assets/fonts/OFL.txt" target="_blank" rel="noopener">Font license ↗</a></div>`
      : `<p class="eyebrow">PREPARE FOR LAUNCH</p><h2 id="dialog-title">AstroPixel: Mission Designer.</h2><p>The game project includes a browser export and Godot source. It works best on a laptop with a keyboard.</p>${PLAY_URL ? "<p><strong>In your browser:</strong> no download or login. It takes about a minute to load.</p>" : "<p><strong>In your browser:</strong> coming soon.</p>"}<p><strong>From source:</strong> download the game repository, open <code>game/project.godot</code> in Godot 4.7.2 and press F5.</p><div class="dialog-links">${PLAY_URL ? `<a class="button" href="${PLAY_URL}" target="_blank" rel="noopener">PLAY IN YOUR BROWSER ↗</a>` : ""}<a class="${PLAY_URL ? "quiet-link" : "button"}" href="${GAME_REPO_URL}" target="_blank" rel="noopener">GAME SOURCE ON GITHUB ↗</a></div>`;
  el("dialog-content").innerHTML = contents;
  dialog.showModal();
  reveal(dialog, 12);
}
el("play-button").addEventListener("click", () => openDialog("game"));
el("credits-button").addEventListener("click", () => openDialog("credits"));
el("close-dialog").addEventListener("click", () => dialog.close());
dialog.addEventListener("click", (event) => {
  if (event.target !== dialog) return;
  const r = dialog.getBoundingClientRect();
  if (
    event.clientX < r.left ||
    event.clientX > r.right ||
    event.clientY < r.top ||
    event.clientY > r.bottom
  )
    dialog.close();
});
el("section-status").setAttribute("role", "status");
el("section-status").setAttribute("aria-live", "polite");
selectScience(0, false);
selectMember(0, false);
updateConsole();
navigate(location.hash.slice(1), false);
