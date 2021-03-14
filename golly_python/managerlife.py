from operator import indexOf
import json


class GOL(object):
    team_names: list = []
    columns = 0
    rows = 0

    def __init__(self, **kwargs):
        self.load_config(**kwargs)
        self.create_life()

    def __repr__(self):
        s = []
        s.append("+" + "-" * (self.columns) + "+")
        for i in range(self.rows):
            row = "|"
            for j in range(self.columns):
                if self.is_alive(j, i):
                    color = self.get_cell_color(j, i)
                    if color == 1:
                        row += "#"
                    elif color == 2:
                        row += "o"
                    else:
                        row += "?"
                else:
                    row += "."
            row += "|"
            s.append(row)
        s.append("+" + "-" * (self.columns) + "+")
        rep = "\n".join(s)
        rep += "\n"

        livecounts = self.get_live_counts()

        rep += "\nGeneration: %d" % (self.generation)
        rep += "\nLive cells, color 1: %d" % (livecounts["liveCells1"])
        rep += "\nLive cells, color 2: %d" % (livecounts["liveCells2"])
        rep += "\nLive cells, total: %d" % (livecounts["liveCells"])
        rep += "\nVictory Percent: %0.1f %%" % (livecounts["victoryPct"])
        rep += "\nCoverage: %0.2f %%" % (livecounts["coverage"])
        rep += "\nTerritory, color 1: %0.2f %%" % (livecounts["territory1"])
        rep += "\nTerritory, color 2: %0.2f %%" % (livecounts["territory2"])

        return rep

    def load_config(self, **kwargs):
        """Load configuration from user-provided input params"""
        if "s1" in kwargs and "s2" in kwargs:
            self.ic1 = kwargs["s1"]
            self.ic2 = kwargs["s2"]
        else:
            raise Exception("ERROR: s1 and s2 parameters must both be specified")

        if "rows" in kwargs and "columns" in kwargs:
            self.rows = kwargs["rows"]
            self.columns = kwargs["columns"]
        else:
            raise Exception(
                "ERROR: rows and columns parameters must be provided to GOL constructor"
            )

        if "team1" in kwargs and "team2" in kwargs:
            self.team_names = [kwargs["team1"], kwargs["team2"]]
        else:
            self.team_names = ["Team 1", "Team 2"]

        # Whether to stop when a victor is detected
        if "halt" in kwargs:
            self.halt = kwargs["halt"]
        else:
            self.halt = True
        self.found_victor = False

        # Neighbor color legacy mode was used in Seasons 1-3
        if "neighbor_color_legacy_mode" in kwargs:
            self.neighbor_color_legacy_mode = kwargs["neighbor_color_legacy_mode"]
        else:
            self.neighbor_color_legacy_mode = False

    def create_life(self):
        s1 = json.loads(self.ic1)
        s2 = json.loads(self.ic2)
        
        self.life = Life(
            s1,
            s2,
            self.rows,
            self.columns,
            self.neighbor_color_legacy_mode
        )





