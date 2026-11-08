import pandas as pd
import pytest
from figure import charger, tracer


def test_charger_colonnes_manquantes(tmp_path):
    fichier = tmp_path / "x.csv"
    fichier.write_text("subject,autre\nS002,1\n")
    with pytest.raises(ValueError):
        charger(fichier)


def test_tracer_cree_le_fichier(tmp_path):
    df = pd.DataFrame({
        "subject": ["S002", "S003"],
        "rem_events_per_hour": [25.0, 30.0],
        "nrem_events_per_hour": [10.0, 12.0],
    })
    sortie = tmp_path / "fig.png"
    tracer(df, str(sortie))
    assert sortie.exists() and sortie.stat().st_size > 0
