'use strict';
const angle = document.getElementById('angle');
const output = document.getElementById('angle-value');
const desktop = document.getElementById('desktop');
const wallpaper = document.getElementById('wallpaper');
const content = document.querySelector('.desktop-content');
const shade = document.getElementById('shade');
const buttons = [...document.querySelectorAll('[data-style]')];
let style = 'paper';
function render() {
  const degrees = Number(angle.value);
  const linear = Math.max(0, Math.min(1, 1 - degrees / 100));
  const progress = linear * linear * (3 - 2 * linear);
  const blur = progress * 0.35 * (style === 'mist' ? 36 : 12) / 5;
  const darkness = Math.min(0.85, progress * 0.45 * (style === 'dusk' ? 1.4 : 0.65));
  desktop.style.transform = `rotateX(${-progress * 76}deg)`;
  wallpaper.style.filter = `blur(${blur}px)`;
  content.style.filter = `blur(${blur}px)`;
  shade.style.opacity = String(darkness);
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
