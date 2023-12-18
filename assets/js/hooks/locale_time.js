export default {
    // need one or more of: mounted | beforeUpdated | updated
    mounted() {
        const t = this.el.textContent.split(":")
                
        const d = new Date()
        d.setUTCHours(t[0])
        d.setUTCMinutes(t[1])
        d.setUTCSeconds(t[2])

        this.el.textContent = d.toLocaleTimeString()
    },
    updated() {
        const t = this.el.textContent.split(":")
                
        const d = new Date()
        d.setUTCHours(t[0])
        d.setUTCMinutes(t[1])
        d.setUTCSeconds(t[2])

        this.el.textContent = d.toLocaleTimeString()
    }
}