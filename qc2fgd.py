import os, datetime, sys

# TODO: put all the baseclasses first

def getQuakeds(qc):
	defOut = ""
	numDefs = 0
	start = 0
	end = 0
	
	while 1:
		start = qc.find("/*FGD",start)
		if start == -1:
			return defOut, numDefs
		#print( "adding ", qc[start + 9 : qc.find(" ",start + 9)] )
		end = qc.find("*/",start)
		defOut += qc[start + 5 : end].strip() + "\n"
		numDefs += 1
		start = end

def getQCs():
	# load every file listed in progs.src except the header
	with open("progs.src",'r') as progsfile:
		progslines = list(progsfile)[1:] # first line is output filename, skip it

	qcfiles = []
	for line in progslines:
		qcfilename = line.partition("//")[0].strip()
		if (len(qcfilename) < 4):
			continue
		if qcfilename[-3:] != ".qc":
			continue
		qcfiles.append(qcfilename)
	return qcfiles


def go():
	cwd = os.path.dirname(os.path.realpath(__file__))
	qcDir = cwd + "\\"
	fgdDir = os.path.normpath(cwd + "\\..\\")
	fgdName = ""
	if len(sys.argv) > 1:
		fgdName = sys.argv[1]
	else:
		fgdName = os.path.basename(fgdDir)
	fgdFile = fgdName + ".fgd"
	fgdDir += "\\"

	print("Scanning *.qc for FGD comments...")
	defOut = """// Copper Quake game definition file (.fgd)
// for Worldcraft 1.6 and above

// If something is wrong with this file, check
//   >  http://lunaran.com/files/copper.fgd  <
// for the very latest version before anything else

// Based heavily on quake.fgd by autolycus/czg/et al
// Generated from Copper QuakeC source comments on """
	numDefs = 0
	defOut += datetime.datetime.now().strftime("%m.%d.%Y")
	defOut += "\n"
	
	# TODO: open quakec in progs.src order for better fgd order control
	qcfiles = getQCs()
	for qcfn in qcfiles:
		if not qcfn.endswith(".qc"):
			continue
		with open(qcDir+qcfn, "r") as qcfile:
			qc = qcfile.read()
		defs, n = getQuakeds(qc)
		if (n):
			defOut += "\n//\n// " + qcfn + "\n//\n"
			defOut += defs
			numDefs += n
			defOut += "\n"
	
	dfn = fgdDir + fgdFile
	print("Writing to",dfn)
	with open(dfn, "w") as df:
		df.write(defOut)
	print("Completed, found",numDefs)

if __name__ == "__main__":
	go()