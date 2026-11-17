```markdown 
# L3: Cisco Baseline Hardening Template

## Objective 
Automate the generation of a secure, "golden config" baseline for Cisco devices using Python and Jinja2.

## Evidence Standard
* **Template:** `baseline.j2` containing the golden config with variables.
* **Script:** `render_template.py` to render the template.
* **Generated Config:** `Meridian-RTR-01.cfg` (The proof).

## The Before/After (Proof of Work)
* **Before:** Manually typing 20+ lines of security config for every new device, risking typos and inconsistency.
* **After:** Running `python3 render_template.py` which generates the secure config instantly.

## Failure Log (Break Phase)
**Hypothesis 1:** Accidentally pasting Cisco config commands into the Python script instead of the template.
*Test:* Ran `python3 render_template.py`.
*Result:* `SyntaxError: invalid syntax`.
*Fix:* Cleared the Python file and separated the logic: `baseline.j2` for Cisco commands, `render_template.py` for Python logic.

**Hypothesis 2:** Changing device variables does not update the output.
*Test:* Changed `hostname` to `Meridian-SW-02` in the Python script and re-ran it.
*Result:* The output correctly generated the new hostname and IPs, proving the Jinja2 template works dynamically.
```
