import os, sys

# gtkradiant doesn't add skill flags by default and I'd rather keep the source 
# clean by adding them here instead, because what else is python for?
def addSkillFlags(deftxt):
	deflines = deftxt.split("\n")
	init = deflines[0]
	initbits = init.split()
	
	cname = initbits[1]
	if (cname == "func_group" or cname.startswith("func_detail") or cname == "worldspawn" or cname == "misc_external_map"):
		return deftxt
		
	if (initbits[5][0] == '('):
		# point ent
		while (len(initbits) < 19):
			initbits.append("?")
	else:
		# brush ent
		while (len(initbits) < 14):
			initbits.append("?")
	initbits += ["NotEasy", "NotNormal", "NotHard", "NotDeathmatch", "CoopOnly", "NotCoop"]
	
	deflines[0] = " ".join(initbits)
	deftxt = "\n".join(deflines)
	return deftxt

def getQuakeds(qc):
	deftxt = ""
	defOut = ""
	numDefs = 0
	start = 0
	end = 0
	
	while 1:
		start = qc.find("/*QUAKED",start)
		if start == -1:
			return defOut, numDefs
		#print( "adding ", qc[start + 9 : qc.find(" ",start + 9)] )
		end = qc.find("*/",start) + 2
		deftxt = addSkillFlags(qc[start : end])
		defOut += "\n" + deftxt + "\n"
		numDefs += 1
		start = end
		

def go():
	cwd = os.path.dirname(os.path.realpath(__file__))
	qcDir = cwd + "\\"
	defDir = os.path.normpath(cwd + "\\..\\")
	defName = ""
	if len(sys.argv) > 1:
		defName = sys.argv[1]
	else:
		defName = os.path.basename(defDir)
	defFile = defName + ".def"
	defDir += "\\"

	print("Scanning *.qc for def comments...")
	defOut = ""
	numDefs = 0
	
	for qcfn in os.listdir(qcDir):
		if not qcfn.endswith(".qc"):
			continue
		with open(qcDir+qcfn, "r") as qcfile:
			qc = qcfile.read()
		defs, n = getQuakeds(qc)
		defOut += defs
		numDefs += n
	
	dfn = defDir + defFile
	print("Writing to",dfn)
	with open(dfn, "w") as df:
		df.write(defOut)
	print("Completed, found",numDefs)

if __name__ == "__main__":
	go()