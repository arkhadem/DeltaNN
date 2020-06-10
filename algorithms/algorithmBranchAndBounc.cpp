#include <stack>
#include <queue>
#include <vector>
#include <unordered_set>
#include <unordered_map>
#include <iostream>
#include <stdlib.h>
#include <time.h>
#include <fstream>

using namespace std;

#define ARRS 256
#define ARR_SIZE 4096

struct INDICES {
    int count;
};

struct  NODE {
    int counts[ARRS];
    int total;
};

struct customCompare {
    bool operator()(const NODE& lhs, const NODE& rhs) {
        int lhsMax = 0;
        int rhsMax = 0;
        for (int i = 0; i < ARRS; ++i) {
            if (lhs.counts[i] > lhsMax) {
                lhsMax = lhs.counts[i];
            }
            if (rhs.counts[i] > rhsMax) {
                rhsMax = rhs.counts[i];
            }
        }
        return lhsMax / lhs.total < rhsMax / rhs.total;
    }
};

unordered_map< int, unordered_set<int> > detectConflicts(INDICES arr[], int** indexArray);
void recurse(INDICES arr[], vector<int> indicesToIncr, unordered_map< int, unordered_set<int> >::iterator &it, unordered_map< int, unordered_set<int> >::iterator &end, stack<NODE> &nodes, int runningTotal);
void randomArray(int arr[]);
void prevValue(int** indexArray);

int main(){

    srand(time(NULL));

    INDICES arr[ARRS];
    NODE initial_node;
    int** indexArray = new int*[ARRS];
    for (int i = 0; i < ARRS; ++i) {
        indexArray[i] = new int[ARR_SIZE];
    }

    ifstream inputFile;
    inputFile.open("fc6_weights_indices.txt");
    for (int i = 0; i < ARRS; ++i) {
        for (int j = 0; j < ARR_SIZE; ++j) {
            if (inputFile.eof()) {
                break;
            }
            inputFile >> indexArray[i][j];
        }
        if (inputFile.eof()) {
            break;
        }
    }
    inputFile.close();

    prevValue(indexArray);

    for (int i = 0; i < ARRS; ++i) {
        //randomArray(array[i]);
        arr[i].count = 0;
        initial_node.counts[i] = 0;
    }

    initial_node.total = 0;

    stack<NODE> nodes;

    int target = ARR_SIZE;
    int totalNodes = 0;
    int best = 0;

    bool metTarget = false;

    while (!metTarget) {
        target = target + 130;
        int runningTotal;
        nodes.push(initial_node);
        while (!nodes.empty()) {
            runningTotal = nodes.top().total;
            //cout << "NODE: ";
            for (int i = 0; i < ARRS; ++i) {
                arr[i].count = nodes.top().counts[i];
                //cout << arr[i].count << " " << array[i][0] << "       ";
            }
            //cout << "    TOTAL: " << runningTotal << endl;
            nodes.pop();

            bool isFinished = true;
            for (int i = 0; i < ARRS; ++i) {
                if (arr[i].count < ARR_SIZE) {
                    isFinished = false;
                }
            }
            if (isFinished) {
                if (runningTotal < target) {
                    best = runningTotal;
                    metTarget = true;
                    break;
                }
            }
            else {
                int minCount = 100000;
                for (int i = 0; i < ARRS; ++i) {
                    if (arr[i].count < minCount) {
                        minCount = arr[i].count;
                    }
                }
                if (runningTotal + (ARR_SIZE - minCount) <= target) {
                    // Increment all indices
                    for (int i = 0; i < ARRS; ++i) {
                        ++arr[i].count;
                    }
                    ++runningTotal;

                    unordered_map< int, unordered_set<int> > conflicts = detectConflicts(arr, indexArray);

                    vector<int> collisions;
                    for (auto it2 = conflicts.begin(); it2 != conflicts.end(); ++it2) {
                        collisions.push_back(it2->second.size());
                        //cout << it2->second.size() << endl;
                    }
                    int totalOptions = 1;
                    for (int i = 0; i < collisions.size(); ++i) {
                        totalOptions *= collisions[i];
                    }
                    //cout << "Options on this column: " << totalOptions << endl;

                    if (!conflicts.empty()) {
                        // Undo increments for arrays in conflicts
                        for (auto it = conflicts.begin(); it != conflicts.end(); ++it) {
                            for (auto it2 = it->second.begin(); it2 != it->second.end(); ++it2) {
                                --arr[*it2].count;
                            }
                        }

                        // Create node for each combination of increments on conflicts
                        auto it = conflicts.begin();
                        auto end = conflicts.end();
                        int stackSize = nodes.size();
                        vector<int> indicesToIncr;
                        recurse(arr, indicesToIncr, it, end, nodes, runningTotal);
                        totalNodes += nodes.size() - stackSize;
                    }
                    else {
                        NODE node;
                        for (int i = 0; i < ARRS; ++i) {
                            node.counts[i] = arr[i].count;
                        }
                        node.total = runningTotal;
                        nodes.push(node);
                    }
                }
            }
        }
    }
    cout << "New number of cycles: " << best << endl;
}



unordered_map< int, unordered_set<int> > detectConflicts(INDICES arr[], int** indexArray) {
    unordered_map< int, unordered_set<int> > conflicts;
    for (int i = 0; i < ARRS; ++i) {
        for (int j = i + 1; j < ARRS; ++j) {
            if (arr[i].count < ARR_SIZE && arr[j].count < ARR_SIZE ) {
                if (indexArray[i][arr[i].count] == indexArray[j][arr[j].count]) {
                    if (conflicts.find(indexArray[i][arr[i].count]) != conflicts.end()) {
                        conflicts[indexArray[i][arr[i].count]].insert(i);
                        conflicts[indexArray[i][arr[i].count]].insert(j);
                    }
                    else {
                        unordered_set<int> temp;
                        temp.insert(i);
                        temp.insert(j);
                        conflicts[indexArray[i][arr[i].count]] = temp;
                    }
                }
            }
        }
    }
    return conflicts;
}



void recurse(INDICES arr[], vector<int> indicesToIncr, unordered_map< int, unordered_set<int> >::iterator &it, unordered_map< int, unordered_set<int> >::iterator &end, stack<NODE> &nodes, int runningTotal) {
    if (it == end) {
        NODE node;
        for (int i = 0; i < ARRS; ++i) {
            node.counts[i] = arr[i].count;
        }
        for (int i = 0; i < indicesToIncr.size(); ++i) {
            ++node.counts[indicesToIncr[i]];
        }
        node.total = runningTotal;
        nodes.push(node);
    }
    else {
        for (auto it2 = it->second.begin(); it2 != it->second.end(); ++it2) {
            indicesToIncr.push_back(*it2);
            auto itCopy = it;
            recurse(arr, indicesToIncr, ++itCopy, end, nodes, runningTotal);
            indicesToIncr.pop_back();
        }
    }
}



void randomArray(int arr[]) {
    vector<int> values;
    for (int i = 0; i < ARR_SIZE; ++i) {
        values.push_back(i);
    }
    for (int i = 0; i < ARR_SIZE; ++i) {
        int v = rand() % values.size();
        //cout << v << " " << values[v] << endl;
        arr[i] = values[v];
        values.erase(values.begin() + v);
    }
}



void prevValue(int** indexArray) {
    int counter = 0;

    vector<int> bubbles[ARRS];
    
    INDICES arr[ARRS];
    for (int i = 0; i < ARRS; ++i) {
        arr[i].count = 0;
    }

    while (true) {

        //cout << counter << endl;

        bool isFinished = true;
        for (int i = 0; i < ARRS; ++i) {
            if (arr[i].count < ARR_SIZE) {
                isFinished = false;
            }
        }

        if (isFinished) {
            break;
        }
   
        ++counter;

        unordered_map< int, unordered_set<int> > conflicts = detectConflicts(arr, indexArray);
        vector<int> minInConflict;

        for (int i = 0; i < ARRS; ++i) {
            ++arr[i].count;
        }
        for (auto it = conflicts.begin(); it != conflicts.end(); ++it) {
            int min = 100000;
            int minIndex = 0;
            for (auto it2 = it->second.begin(); it2 != it->second.end(); ++it2) {
                if (arr[*it2].count < min) {
                    min = arr[*it2].count;
                    minIndex = *it2;
                }
                --arr[*it2].count;
                bubbles[*it2].push_back(arr[*it2].count);
            }
            minInConflict.push_back(minIndex);
        }

        for (int i = 0; i < minInConflict.size(); ++i) {
            ++arr[minInConflict[i]].count;
            bubbles[minInConflict[i]].pop_back();
        }
    }

    cout << "Old number of cycles: " << counter << endl;

    ofstream outputFile;
    outputFile.open("test.txt");

    for (int i = 0; i < ARRS; ++i) {
        for (int j = 0; j < bubbles[i].size(); ++j) {
            outputFile << bubbles[i][j] << " ";
        }
        outputFile << "\n";
    }

    outputFile.close();
}