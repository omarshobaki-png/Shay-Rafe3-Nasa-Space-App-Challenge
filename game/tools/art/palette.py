"""Space Mission Designer palette. Ramps darkest -> lightest."""


def _rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


_HEX = {
    "ol": "0c0a14",
    # cool white paint (rocket, fairing, rover)
    "paint0": "3a4058", "paint1": "6a7290", "paint2": "a3abc4", "paint3": "d6dcea", "paint4": "f4f6fb",
    # near-black carbon (interstage, legs, grid fins)
    "jet0": "121420", "jet1": "1e2232", "jet2": "2e3448", "jet3": "454d66",
    # gold multi-layer insulation foil
    "gold0": "4a2e10", "gold1": "7c5418", "gold2": "b3812a", "gold3": "dcae44", "gold4": "f6dc84",
    # bare metal
    "metal0": "2a2e3a", "metal1": "4e5566", "metal2": "7d8697", "metal3": "b4bcc8", "metal4": "dfe4ea",
    # glass / sensors
    "glass0": "0f2b40", "glass1": "1d5a80", "glass2": "39a0c8", "glass3": "8fe3f5",
    # solar cells
    "cell0": "101a3c", "cell1": "1a2c66", "cell2": "2b4796", "cell3": "4f74c8",
    # tyres / dark rubber
    "tyre0": "16141a", "tyre1": "2a2630", "tyre2": "3e3946",
    # accents
    "red0": "4a1016", "red1": "8c1e22", "red2": "d03a30", "red3": "f07a50",
    "orange0": "6a2a0c", "orange1": "b4501a", "orange2": "f08a2a", "orange3": "ffc060",
}

P = {k: _rgb(v) for k, v in _HEX.items()}
