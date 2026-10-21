// Configuración de Tailwind CSS 3.4.17 para la página web.
// Regenerar tailwind.css (desde la carpeta website):
//   npx tailwindcss@3.4.17 -i tailwind.src.css -o tailwind.css --minify
module.exports = {
  content: ['./*.html'],
  theme: {
    extend: {
      colors: {
        paper: '#FFFFFF',
        mist: '#F3F4F8',
        line: '#E3E4EA',
        ink: '#17171C',
        inksoft: '#4B4B57',
        cobalt: '#2340D9',
        cobaltdeep: '#1A2FA6',
        carmin: '#D11F3A',
        oro: '#F2B705',
        esmeralda: '#00875A',
      },
    },
  },
  plugins: [],
};
