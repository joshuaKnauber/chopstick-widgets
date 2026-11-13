// Finds a Wolt order-tracking tab in Chrome or Safari and reads its ETA.
// Prints { active, status, eta, minutes, venue, url, detail, needs_js }.

ObjC.import('stdlib')

function isRunning(name) {
    return Application('System Events').processes.whose({ name: name }).length > 0
}

function findTab() {
    const isOrder = u => /wolt\.com\/.*\/(order|orders|tracking)\b|track\.wolt\.com/i.test(u || '')
    if (isRunning('Google Chrome')) {
        const chrome = Application('Google Chrome')
        for (const w of chrome.windows()) for (const t of w.tabs()) {
            if (isOrder(t.url())) return {
                url: t.url(), title: t.title(),
                text: () => t.execute({ javascript: 'document.body.innerText' })
            }
        }
    }
    if (isRunning('Safari')) {
        const safari = Application('Safari')
        for (const w of safari.windows()) for (const t of w.tabs()) {
            if (isOrder(t.url())) return {
                url: t.url(), title: t.name(),
                text: () => safari.doJavaScript('document.body.innerText', { in: t })
            }
        }
    }
    return null
}

function parse(text) {
    const out = {}
    const lower = text.toLowerCase()
    const statuses = [
        [/delivered|zugestellt|geliefert|enjoy your/, 'Delivered'],
        [/on (its|the) way|picked up|courier is coming|unterwegs|abgeholt/, 'On the way'],
        [/being prepared|preparing|wird zubereitet|zubereitung/, 'Being prepared'],
        [/received|confirmed|bestätigt|angenommen/, 'Order received'],
    ]
    for (const [re, label] of statuses) if (re.test(lower)) { out.status = label; break }

    const range = text.match(/(\d{1,3})\s*[–-]\s*(\d{1,3})\s*min/i)
    const single = text.match(/(\d{1,3})\s*min/i)
    if (range) { out.minutes = Number(range[1]); out.eta = range[1] + '–' + range[2] + ' min' }
    else if (single) { out.minutes = Number(single[1]); out.eta = single[1] + ' min' }

    const clock = text.match(/(?:arriv\w*|estimated|ankunft|lieferung)[^\n\d]{0,30}(\d{1,2}[:.]\d{2})/i)
    if (clock) out.at = clock[1].replace('.', ':')
    if (out.at) out.detail = 'Arrives around ' + out.at
    if (!out.eta && out.at) out.eta = out.at
    return out
}

function run() {
    const tab = findTab()
    if (!tab) return JSON.stringify({ active: false })
    const result = { active: true, url: tab.url, venue: (tab.title || 'Wolt').replace(/\s*[|–-]\s*Wolt.*$/i, '') }
    try {
        Object.assign(result, parse(String(tab.text() || '')))
    } catch (e) {
        result.needs_js = true
        result.status = 'Tracking tab found'
        result.detail = 'To read the ETA, turn on View › Developer › Allow JavaScript from Apple Events (Chrome) or Develop › Allow JavaScript from Apple Events (Safari).'
    }
    if (result.status === 'Delivered') result.active = false, result.delivered = true
    return JSON.stringify(result)
}
