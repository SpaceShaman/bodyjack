# bodyjack

Gra zbudowana w Godot 4.7.2.

Publikacja na GitHub Pages uruchamia się po każdym pushu do gałęzi `master`:

```bash
git push origin master
```

Gałąź musi zawierać `.github/workflows/pages.yml` i `src/export_presets.cfg`.
Workflow eksportuje preset `Web` i aktualizuje stronę gry.

W repozytorium ustaw **Settings → Pages → Source: GitHub Actions**.
Jeżeli środowisko `github-pages` ogranicza wdrożenia do wybranych gałęzi,
w **Settings → Environments → github-pages** dopuść gałąź `master`.
