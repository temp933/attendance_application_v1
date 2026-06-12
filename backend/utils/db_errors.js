const FIELD_LABELS = {
  admin_email: "Admin email",
  hr_email: "HR email",
  contact_number: "Contact number",
  domain_name: "Domain name",
  gst_number: "GST number",
  username: "Username",
  email_id: "Email",
  phone_number: "Phone number",
  aadhar_number: "Aadhar number",
  pan_number: "PAN number",
  pf_number: "PF number",
  esic_number: "ESIC number",
};

function getDuplicateFieldLabel(err) {
  if (err.code !== "ER_DUP_ENTRY") return null;
  const match = err.sqlMessage?.match(/for key '(?:.*\.)?(.+)'/);
  const keyName = match ? match[1] : "";
  if (FIELD_LABELS[keyName]) return FIELD_LABELS[keyName];
  for (const [field, label] of Object.entries(FIELD_LABELS)) {
    if (keyName.toLowerCase().includes(field.toLowerCase())) return label;
  }
  return "value";
}

module.exports = { getDuplicateFieldLabel };
