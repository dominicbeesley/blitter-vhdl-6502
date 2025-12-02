#!/usr/bin/env python

import math
import json

def checkint(a, msg):
	if (math.ceil(a) != math.floor(a)):
		raise Exception(msg)
	return int(a)

def wraparound(s):
	if len(s) > 0:
		return s[0] + s + s[-1]
	else:
		return ""

def multidot(s):
	if len(s) > 2:
		ret = s[0]
		for i in range(1, len(s)):
			if s[i] == s[i-1]:
				ret = ret + "."
			else:
				ret = ret + s[i]

		return ret
	else:
		return s

# bus/cpu speed choices
CPU_speed = 8
FB_speed = 128

# timing constraints
T_ADS = 40	# address setup from phi2
T_DHR = 10  # 
T_DSR = 10
T_PCS = 10
T_MDS = 30

CPU_period = 1000 / CPU_speed
FB_period = 1000 / FB_speed

D_TOTAL = checkint(CPU_period / FB_period, "D_TOTAL not divisible by 2")
D_PHI1  = 0
D_PHI2  = math.ceil(D_TOTAL / 2)
D_ADS   = math.ceil(T_ADS / FB_period)
D_P1DHR = math.ceil(T_DHR / FB_period)
D_P2DHR = D_PHI2 + math.ceil(T_DHR / FB_period)
D_MDS   = D_PHI2 + math.ceil(T_MDS / FB_period)

D_P2DSR = D_TOTAL - max([math.ceil(T_DSR / FB_period), math.ceil(T_PCS / FB_period)])

lab_dict = {
	"ADS": D_ADS,
	"1DHR": D_P1DHR,
	"2DHR": D_P2DHR,
	"MDS": D_MDS,
	"DSR": D_P2DSR
}

labels = [""] * D_TOTAL

for k in lab_dict:
	labels[lab_dict[k]] = k


#################################### Show results ############################

print("==================== SPECIFIED VALUES =================================")


print(f"CPU_speed       :{CPU_speed:12.10g} MHz");
print(f"FB_speed        :{FB_speed:12.10g} MHz");

print(f"T_ADS           :{T_ADS:12.10g}ns")
print(f"T_DHR           :{T_DHR:12.10g}ns")
print(f"T_DSR           :{T_DSR:12.10g}ns")
print(f"T_PCS           :{T_PCS:12.10g}ns")
print(f"T_MDS           :{T_MDS:12.10g}ns")

print("==================== CALCULATED VALUES =================================")


w_CPU_A_nOE = "".join(
		map(
			lambda n: "0" if n + 1 == D_ADS or n + 1 == D_ADS + 1 else "1",
			range(0, D_TOTAL)
		)
	)

w_CPU_A_nOE = multidot(wraparound(w_CPU_A_nOE))

print(json.dumps(
		{"signal": [
			{ "wave": "=" * (D_TOTAL + 2), "data": [D_TOTAL-1] + list(range(0, D_TOTAL)) + [0]},
			{ "name": "div", "wave": "=" * (D_TOTAL + 2), "data": [""] + labels + [""]},
			{ "name": "clk", "wave": "p" + "." * (D_TOTAL + 1)},
			{ "name": "phi2", "wave": "hl" + "." * (D_PHI2 - 1) + "h" + "." * (D_TOTAL-D_PHI2-1) + "l"},
			{ "name": "CPU_A_nOE", "wave": w_CPU_A_nOE}
		]}
	))