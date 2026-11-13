from pathlib import Path

import pytest
from analyse import frequency_per_hour, is_marked, analyze_csv

EN_TETE = "TIMESTAMP,Sleep_Stage,Obstructive_Apnea,Central_Apnea,Hypopnea,Multiple_Events\n"


def test_frequence_simple():
    # 10 événements en 2 heures (7200 s) = 5 par heure
    assert frequency_per_hour(10, 7200) == 5.0


def test_frequence_duree_zero():
    # Durée nulle : doit renvoyer None, pas planter
    assert frequency_per_hour(5, 0) is None


def test_is_marked():
    assert is_marked("1") is True
    assert is_marked("0") is False
    assert is_marked("") is False
    assert is_marked(None) is False
    assert is_marked("NaN") is False


def test_analyze_csv_episodes(tmp_path):
    # 8 lignes, une toutes les 900 s : 4 lignes REM = 1 h, 4 lignes NREM = 1 h
    # REM : 2 épisodes. NREM : 1 épisode
    lignes = [
        "0,R,1,0,0,0", "900,R,1,0,0,0", "1800,R,0,0,0,0", "2700,R,1,0,0,0",
        "3600,N2,0,0,0,0", "4500,N2,0,0,1,0", "5400,N2,0,0,1,0", "6300,N2,0,0,0,0",
    ]
    fichier = tmp_path / "S999_whole_df.csv"
    fichier.write_text(EN_TETE + "\n".join(lignes) + "\n")
    rapport = analyze_csv(fichier)
    assert rapport["total_event_episodes_by_phase"] == {"REM": 2, "NREM": 1}
    assert rapport["sleep_phase_hours"]["REM"] == 1.0
    assert rapport["events_per_hour_by_phase"]["REM"] == 2.0
    assert rapport["events_per_hour_by_phase"]["NREM"] == 1.0


def test_analyze_csv_without_optional_multiple_events(tmp_path):
    fichier = tmp_path / "sans_multiple_events.csv"
    fichier.write_text(
        "TIMESTAMP,Sleep_Stage,Obstructive_Apnea,Central_Apnea,Hypopnea\n"
        "0,R,1,0,0\n"
        "1,R,0,0,0\n"
    )

    rapport = analyze_csv(fichier)

    assert rapport["total_event_episodes_by_phase"] == {"REM": 1, "NREM": 0}
    assert rapport["event_episode_counts"].get("Multiple_Events", 0) == 0


def test_fichier_manquant(tmp_path):
    with pytest.raises(FileNotFoundError):
        analyze_csv(tmp_path / "nexiste_pas.csv")


def test_colonne_manquante(tmp_path):
    fichier = tmp_path / "mauvais.csv"
    fichier.write_text("TIMESTAMP,Sleep_Stage\n0,R\n1,R\n")
    with pytest.raises(ValueError):
        analyze_csv(fichier)


def test_timestamps_irreguliers_refuses(tmp_path):
    fichier = tmp_path / "irregulier.csv"
    fichier.write_text(
        EN_TETE
        + "0,R,0,0,0,0\n"
        + "1,R,1,0,0,0\n"
        + "3,R,0,0,0,0\n"
    )

    with pytest.raises(ValueError, match="régulièrement échantillonnés"):
        analyze_csv(fichier)


def test_multiple_events_est_un_type_annote_et_total_est_une_union(tmp_path):
    fichier = tmp_path / "multiple.csv"
    fichier.write_text(
        EN_TETE
        + "0,R,0,0,0,1\n"
        + "1,R,0,0,0,1\n"
        + "2,R,1,0,0,1\n"
        + "3,R,0,0,0,0\n"
    )

    rapport = analyze_csv(fichier)

    assert rapport["total_event_episodes_by_phase"] == {"REM": 1, "NREM": 0}
    assert rapport["event_episode_counts_by_phase"]["Multiple_Events"] == {
        "REM": 1,
        "NREM": 0,
    }
    assert rapport["event_episode_counts_by_phase"]["Obstructive_Apnea"] == {
        "REM": 1,
        "NREM": 0,
    }


def test_fixtures_match_documented_episode_counts():
    fixture_dir = Path(__file__).parents[1] / "data" / "exemple"
    expected = {
        "exemple_filtre.csv": (2, 5),
        "exemple_sans_evenement.csv": (0, 0),
        "exemple_sans_rem.csv": (0, 2),
    }

    for filename, counts in expected.items():
        rapport = analyze_csv(fixture_dir / filename)
        assert (
            rapport["total_event_episodes_by_phase"]["REM"],
            rapport["total_event_episodes_by_phase"]["NREM"],
        ) == counts
