module main;

import std.stdio;
import std.conv;
import std.csv;
import std.file;
import std.algorithm;
import std.parallelism;
import std.datetime;
import std.concurrency, core.thread;

struct Layout
{
	string a;
	string b;
	string c;
	string d;
	string e;
	string f;
	string g;
	string h;
	string i;
	string j;
}

shared 
	int[string] counts;
shared 
	int sat=0, unsat=0;

void getTopFeatureRequests() {
	bool stopped = false;
	while(!stopped)
	receive(
		(bool end) { stopped = true; },
		(Layout record) {
			if(startsWith(record.d, "I a") || startsWith(record.c, "Every d")) ++sat;
			else {
				++unsat;
				//if(!startsWith(record.c, "Have not")) continue; // have NOT used brackets
				if(record.d) {
					auto requests = csvReader!(string, Malformed.ignore)(record.d,'^');
					foreach(ref x; requests){
						foreach(ref y; x) ++counts[y.idup];
					}
				}
			}
		}
	);

	send(ownerTid, true);
}

void main(string[] args)
{
	//scope bench = new Timer();

	writeln("Opening CSV...");
	StopWatch sw;
	sw.start();
	auto data = File("tabdata.csv", "r");
	writeln(  "Loading done." );

	auto records = csvReader!Layout(data.byLine().joiner("\n"));
	auto tid = spawn(&getTopFeatureRequests);
	foreach(ref record; records) {
		send(tid, record);
	}
	send(tid, true); // tell it to end

	receiveOnly!bool(); //wait untill finish flag

	writefln("=== Usat: %d, sat: %d", unsat, sat);
	auto t(string a, string b) {
		return counts[a] > counts[b];
	}
	string[] keys = counts.keys;
	sort!t(keys);
	sw.stop();
	int ftotal=0;
	foreach(ref k; keys) if(counts[k] > 2) writefln("%s -- %s", k, to!string(counts[k]));
	writeln( "file closed, microseconds time:", sw.peek().usecs );
}

