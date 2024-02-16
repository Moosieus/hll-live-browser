export function localizeTimestamp() {
    const t = this.el.textContent.split(":")
    
    const d = new Date()
    d.setUTCHours(t[0])
    d.setUTCMinutes(t[1])
    d.setUTCSeconds(t[2])

    this.el.textContent = d.toLocaleTimeString()
}

export default {
    mounted: localizeTimestamp,
    updated: localizeTimestamp,
}