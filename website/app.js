'use strict';
const angle = document.getElementById('angle');
const output = document.getElementById('angle-value');
const desktop = document.getElementById('desktop');
const wallpaper = document.getElementById('wallpaper');
const content = document.querySelector('.desktop-content');
const shade = document.getElementById('shade');
const paperFinish = document.getElementById('paper-finish');
const buttons = [...document.querySelectorAll('[data-style]')];
let style = 'mist';
function render() {
  const degrees = Number(angle.value);
  const linear = Math.max(0, Math.min(1, 1 - degrees / 100));
  const progress = linear * linear * (3 - 2 * linear);
  const blur = progress * progress * 0.35 * ({ paper: 2, dusk: 12, mist: 28 }[style]) * desktop.clientWidth / 1440;
  const darkness = Math.min(0.96, progress * 0.45 * ({ paper: 0.10, dusk: 2.1, mist: 0.12 }[style]));
  const paper = style === 'paper' ? progress * 0.45 : 0;
  desktop.style.transform = `rotateX(${-progress * 76}deg)`;
  wallpaper.style.filter = `blur(${blur}px) saturate(${1 - paper * 0.65})`;
  content.style.filter = `blur(${blur}px) saturate(${1 - paper * 0.65})`;
  shade.style.opacity = '1';
  shade.style.background = `linear-gradient(to bottom, rgba(0,0,0,${1 - Math.pow(1 - darkness, 1 / 2.2)}), rgba(0,0,0,${1 - Math.pow(1 - darkness * 0.7, 1 / 2.2)}))`;
  paperFinish.style.opacity = String(paper);
  output.value = `${degrees}°`;
  angle.setAttribute('aria-valuetext', `${degrees} degrees`);
}
angle.addEventListener('input', render);
buttons.forEach(button => button.addEventListener('click', () => {
  style = button.dataset.style;
  buttons.forEach(item => item.setAttribute('aria-pressed', String(item === button)));
  document.getElementById('style-label').textContent = button.textContent;
  render();
}));
render();
