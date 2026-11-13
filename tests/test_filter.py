import csv
import subprocess
from pathlib import Path


def test_filter_handles_quoted_csv_and_preserves_multiple_events(tmp_path):
    source = tmp_path / "raw.csv"
    destination = tmp_path / "nested" / "filtered.csv"
    source.write_text(
        '"TIMESTAMP","Sleep_Stage","Obstructive_Apnea","Central_Apnea",'
        '"Hypopnea","Multiple_Events","note"\n'
        '"0.0","P","","","","","before"\n'
        '"0.015625","R","","","","1","quoted, comma"\n'
        '"0.03125","W","0","0","1","","wake"\n'
        '"0.046875","Missing","1","","","","ignored"\n',
        encoding="utf-8",
    )
    destination.parent.mkdir()

    subprocess.run(
        [
            "bash",
            "scripts/filtrer_phases_sommeil.sh",
            "-f",
            str(source),
            "-o",
            str(destination),
        ],
        check=True,
        capture_output=True,
        text=True,
    )

    with destination.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))

    assert rows == [
        {
            "TIMESTAMP": "0.015625",
            "Sleep_Stage": "R",
            "Obstructive_Apnea": "0",
            "Central_Apnea": "0",
            "Hypopnea": "0",
            "Multiple_Events": "1",
        },
        {
            "TIMESTAMP": "0.03125",
            "Sleep_Stage": "W",
            "Obstructive_Apnea": "0",
            "Central_Apnea": "0",
            "Hypopnea": "1",
            "Multiple_Events": "0",
        },
    ]
