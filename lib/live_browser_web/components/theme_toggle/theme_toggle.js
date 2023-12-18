const toggle_light = document.getElementById('toggle_light')
const toggle_system = document.getElementById('toggle_system')
const toggle_dark = document.getElementById('toggle_dark')

window.addEventListener("phx:page-loading-stop", function(_) {
    // *.dataset.active defaults to 'false'
    switch (localStorage.getItem('theme')) {
        case 'light':
            toggle_light.dataset.active = 'true'
            break;

        case 'dark':
            toggle_dark.dataset.active = 'true'
            break;

        case null:
            toggle_system.dataset.active = 'true'
            break;
    }
})

toggle_light.addEventListener('click', function(e) {
    localStorage.setItem('theme', 'light')
    toggle_theme()
    toggle_light.dataset.active = 'true'
    toggle_system.dataset.active = 'false'
    toggle_dark.dataset.active = 'false'
})

toggle_system.addEventListener('click', function(e) {
    localStorage.removeItem('theme')
    toggle_theme()
    toggle_light.dataset.active = 'false'
    toggle_system.dataset.active = 'true'
    toggle_dark.dataset.active = 'false'
})

toggle_dark.addEventListener('click', function(e) {
    localStorage.setItem('theme', 'dark')
    toggle_theme()
    toggle_light.dataset.active = 'false'
    toggle_system.dataset.active = 'false'
    toggle_dark.dataset.active = 'true'
})
