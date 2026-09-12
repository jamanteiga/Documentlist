// Utilidades compartidas: fechas, badges de estado y calculo de alertas.

export function fmtDate(d) {
  if (!d) return '-';
  const dt = new Date(d + 'T00:00:00');
  if (isNaN(dt)) return '-';
  return dt.toLocaleDateString('es-ES');
}

export function todayISO() {
  return new Date().toISOString().slice(0, 10);
}

export function daysSince(dateStr) {
  if (!dateStr) return null;
  const d = new Date(dateStr + 'T00:00:00');
  const now = new Date();
  now.setHours(0, 0, 0, 0);
  return Math.round((now - d) / 86400000);
}

// statusMap: { CODE: {description, category, color} }
export function statusBadge(code, statusMap) {
  if (!code) return '<span class="muted">-</span>';
  const info = statusMap[code];
  if (!info) return `<span class="badge" style="background:#6b7280">${code}</span>`;
  return `<span class="badge" style="background:${info.color}" title="${info.description}">${code}</span>`;
}

// Calcula el estado de alerta de un documento a partir de su ultimo evento
// y de la fecha de entrega contractual.
// Devuelve { level: 'ok'|'warn'|'danger', reason: string }
export function computeAlert(doc, lastEvent, statusMap, reviewDays) {
  const cat = lastEvent && lastEvent.status ? (statusMap[lastEvent.status]?.category) : null;

  // Sin ningun envio todavia
  if (!lastEvent) {
    if (doc.delivery_date && doc.delivery_date < todayISO()) {
      const d = daysSince(doc.delivery_date);
      return { level: 'danger', reason: `Sin enviar, ${d} dias tras la fecha prevista` };
    }
    return { level: 'ok', reason: 'Pendiente de primer envio' };
  }

  if (lastEvent.event_type === 'ENVIADO') {
    const d = daysSince(lastEvent.event_date);
    if (d > reviewDays) {
      return { level: 'danger', reason: `Enviado hace ${d} dias, sin respuesta (plazo ${reviewDays}d)` };
    }
    if (d > Math.floor(reviewDays * 0.7)) {
      return { level: 'warn', reason: `Enviado hace ${d} dias, esperando respuesta` };
    }
    return { level: 'ok', reason: `Enviado hace ${d} dias` };
  }

  // Ultimo evento RECIBIDO
  if (cat === 'PENDIENTE') {
    const d = daysSince(lastEvent.event_date);
    if (d > reviewDays) return { level: 'danger', reason: `Estado pendiente desde hace ${d} dias` };
    return { level: 'warn', reason: `Estado pendiente (${lastEvent.status})` };
  }
  if (cat === 'RECHAZADO') {
    return { level: 'danger', reason: 'Rechazado - requiere reenvio' };
  }
  return { level: 'ok', reason: 'Al dia' };
}

export function escapeHtml(str) {
  if (str === null || str === undefined) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
