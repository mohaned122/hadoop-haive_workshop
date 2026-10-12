# Answer encryption (cheat-prevention)

We obfuscate the correct answer indices so casual inspection doesn't reveal them.

## What we did
- Extracted `answers = [q.correct_index for q in quiz_questions.txt]` (length 31)
- XOR-encrypted with key `hwquiz` (bytes) → Base64 → written to `answers.enc`
- Built `index.html` with the encrypted blob (`ENC = "..."`) and a small JS XOR decoder (`xorDec`) that runs at page load
- Replaced all `"answer": N` with `"answer": -1` in the embedded `QUESTIONS` array
- After shuffling/assigning `qlist = pool.map(...)`, we restore `answer = ANSWERS[i]` (from the decrypted array)
- Console app (`quiz_app.py`) still reads `quiz_questions.txt` directly and computes correct indices at runtime (unmodified). The Python path is not "protected" by this XOR; this change targets the static HTML delivery.

## Key files
- `answers.enc` — Base64/XOR blob of `[0,1,2,...]` indices (ASCII). Do not commit/share in a trivially readable form if you want stronger protection; for a workshop this is sufficient deterrent.
- `index.html` — now contains the encrypted answers and restoration logic.

## Regenerate answers.enc / re-protect index
Run from this folder (PowerShell):

```powershell
python -c @"
import base64,json
key=b'hwquiz'
from quiz_data import load_questions
qs,w=load_questions('quiz_questions.txt')
answers=[q.correct_index for q in qs]
def enc(x):
    s=json.dumps(x); b=s.encode('utf-8')
    r=bytes([b[i]^key[i%len(key)] for i in range(len(b))])
    return base64.b64encode(r).decode('ascii')
open('answers.enc','w',encoding='ascii').write(enc(answers))
"@
```

Then rebuild the protected HTML (or regenerate from scratch). If you edit questions, **regenerate** `answers.enc` and re-embed it in `index.html`.

## Notes
- The key is embedded client-side (obfuscation, not strong cryptography). A determined user could extract it, but it raises the bar vs. plaintext JSON.
- To make it harder: rotate the key, minify/uglify `index.html`, or split the blob. For "least internet resource consumption" we kept it tiny and readable.
- Console quiz remains the authoritative/traditional path and unchanged.