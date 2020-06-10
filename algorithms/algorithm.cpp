#include <stack>
#include <queue>
#include <vector>
#include <unordered_set>
#include <unordered_map>
#include <iostream>
#include <sstream>
#include <stdlib.h>
#include <time.h>
#include <fstream>
#include <algorithm>
#include <string>
#include <sstream>

using namespace std;

string FILENAME = "fc8_W_weights_indices.txt";

int ARRS = 0;
int ARR_SIZE = 0;

struct INDICES {
    int count;
};

struct NODE {
    vector<int> counts;
    int total;
};

// struct customCompare {
//     bool operator()(const NODE& lhs, const NODE& rhs) {
//         int lhsMax = 0;
//         int rhsMax = 0;
//         for (int i = 0; i < ARRS; ++i) {
//             if (lhs.counts[i] > lhsMax) {
//                 lhsMax = lhs.counts[i];
//             }
//             if (rhs.counts[i] > rhsMax) {
//                 rhsMax = rhs.counts[i];
//             }
//         }
//         return lhsMax / lhs.total < rhsMax / rhs.total;
//     }
// };

unordered_map< int, unordered_set<int> > detectConflicts(vector<INDICES> &arr, vector< vector<int> > &indexArray, int i);
void recurse(vector<INDICES> &arr, unordered_map< int, unordered_set<int> >::iterator &it, unordered_map< int, unordered_set<int> >::iterator &end, vector<NODE> &nodes, int runningTotal, int leastBubbles);
void prevValue(vector< vector<int> > &indexArray);
void reorder(vector< vector<int> > &indexArray);

int main(){

    srand(time(NULL));

    vector< vector<int> > indexArray;

    ifstream inputFile;
    inputFile.open(FILENAME);
    string line;
    while (getline(inputFile, line)) {
        stringstream ss;
        vector<int> temp;
        indexArray.push_back(temp);
        ss.str(line);
        int ind;
        while(ss >> ind) {
            if (ind != -1) {
                indexArray[ARRS].push_back(ind);
                ++ARR_SIZE;
            }
        }
        ++ARRS;
    }
    inputFile.close();

    ARR_SIZE = ARR_SIZE / ARRS;

    cout << "Rows: " << ARRS << ", Row length: " << ARR_SIZE << endl;

    //Calculate deltas
    int deltaCount = 0;
    int deltaCount2 = 0;
    int count = 0;
    for (int i = 0; i < ARRS; ++i) {
        for (int j = 1; j < ARR_SIZE; ++j) {
            if ((indexArray[i][j] - indexArray[i][j-1] <= 16) && (indexArray[i][j] - indexArray[i][j-1] > 0)) {
                ++deltaCount;
            }
            if ((indexArray[i][j] - indexArray[i][j-1] <= 8) && (indexArray[i][j] - indexArray[i][j-1] > 0)) {
                ++deltaCount2;
            }
            ++count;
        }
    }
    double fraction = (double)deltaCount / (double)count;
    cout << "Fraction of values that can be represented as 4-bit deltas: " << fraction << endl;
    double fraction2 = (double)deltaCount2 / (double)count;
    cout << "Fraction of values that can be represented as 3-bit deltas: " << fraction2 << endl;

    prevValue(indexArray);

    reorder(indexArray);

    prevValue(indexArray);

    NODE initial_node;
    initial_node.counts.resize(ARRS);
    vector<INDICES> arr;
    arr.resize(ARRS);
    for (int i = 0; i < ARRS; ++i) {
        arr[i].count = 0;
        initial_node.counts[i] = 0;
    }

    initial_node.total = 0;

    vector<NODE> nodes;
    nodes.push_back(initial_node);

    int bestTotal = 100000;
    int totalNodes = 0;

    // for (int i = 0; i < 1+((ARRS-1)/256); ++i) {

    //     while (!nodes.empty()) {
    //         int runningTotal = nodes.back().total;
    //         for (int j = 0; j < min(256, ARRS); ++j) {
    //             arr[i*256+j].count = nodes.back().counts[i*256+j];
    //         }
    //         nodes.pop_back();

    //         bool isFinished = true;
    //         for (int j = 0; j < min(256, ARRS); ++j) {
    //             if (arr[i*256+j].count < ARR_SIZE) {
    //                 isFinished = false;
    //             }
    //         }
    //         if (isFinished) {
    //             if (runningTotal < bestTotal) {
    //                 bestTotal = runningTotal;
    //             }
    //         }
    //         else {
    //             int minCount = 100000;
    //             for (int j = 0; j < min(256, ARRS); ++j) {
    //                 if (arr[i*256+j].count < minCount) {
    //                     minCount = arr[i*256+j].count;
    //                 }
    //             }
    //             if (runningTotal + (ARR_SIZE - minCount) < bestTotal) {
    //                 // Increment all indices
    //                 for (int j = 0; j < ARRS; ++j) {
    //                     ++arr[i*256+j].count;
    //                 }
    //                 ++runningTotal;

    //                 unordered_map< int, unordered_set<int> > conflicts = detectConflicts(arr, indexArray, i);

    //                 vector<int> collisions;
    //                 for (auto it2 = conflicts.begin(); it2 != conflicts.end(); ++it2) {
    //                     collisions.push_back(it2->second.size());
    //                     //cout << it2->second.size() << endl;
    //                 }
    //                 int totalOptions = 1;
    //                 for (int j = 0; j < collisions.size(); ++j) {
    //                     totalOptions *= collisions[j];
    //                 }
    //                 // cout << "Options on this column: " << totalOptions << endl;

    //                 if (!conflicts.empty()) {
    //                     // Undo increments for arrays in conflicts
    //                     for (auto it = conflicts.begin(); it != conflicts.end(); ++it) {
    //                         for (auto it2 = it->second.begin(); it2 != it->second.end(); ++it2) {
    //                             --arr[*it2].count;
    //                         }
    //                     }

    //                     // Create node for each combination of increments on conflicts
    //                     auto it = conflicts.begin();
    //                     auto end = conflicts.end();
    //                     int stackSize = nodes.size();
    //                     int size = nodes.size();

    //                     int leastBubbles;
    //                     for (int j = 0; j < nodes.size(); ++j) {
    //                         int maxBubbles = 0;
    //                         for (int k = 0; k < ARRS; ++k) {
    //                             if (nodes[j].total - nodes[j].counts[k] > maxBubbles) {
    //                                 maxBubbles = nodes[j].total - nodes[j].counts[k];
    //                             }
    //                         }
    //                         if (maxBubbles < leastBubbles) {
    //                             leastBubbles = maxBubbles;
    //                         }
    //                     }

    //                     while (size == nodes.size()) {
    //                         recurse(arr, it, end, nodes, runningTotal, leastBubbles);
    //                         ++leastBubbles;
    //                     }
    //                     totalNodes += nodes.size() - stackSize;
    //                 }
    //                 else {
    //                     NODE node;
    //                     node.counts.resize(ARRS);
    //                     for (int j = 0; j < min(256, ARRS); ++j) {
    //                         node.counts[i*256+j] = arr[i*256+j].count;
    //                     }
    //                     node.total = runningTotal;
    //                     nodes.push_back(node);
    //                 }
    //             }
    //         }

    //         //cout << totalNodes << endl;
    //         //cout << nodes.size() << " ";
    //         //cout << nodes.back().counts[0] << endl;
    //     }

    // }

    // cout << "New number of cycles: " << bestTotal << endl;

}



unordered_map< int, unordered_set<int> > detectConflicts(vector<INDICES> &arr, vector< vector<int> > &indexArray, int i) {
    unordered_map< int, unordered_set<int> > conflicts;
    for (int j = 0; j < min(256, ARRS); ++j) {
        for (int k = j + 1; k < min(256, ARRS); ++k) {
            if (arr[i*256+j].count < ARR_SIZE && arr[i*256+k].count < ARR_SIZE ) {
                if (indexArray[i*256+j][arr[i*256+j].count] == indexArray[i*256+k][arr[i*256+k].count]) {
                    if (conflicts.find(indexArray[i*256+j][arr[i*256+j].count]) != conflicts.end()) {
                        conflicts[indexArray[i*256+j][arr[i*256+j].count]].insert(i*256+j);
                        conflicts[indexArray[i*256+j][arr[i*256+j].count]].insert(i*256+k);
                    }
                    else {
                        unordered_set<int> temp;
                        temp.insert(i*256+j);
                        temp.insert(i*256+k);
                        conflicts[indexArray[i*256+j][arr[i*256+j].count]] = temp;
                    }
                }
            }
        }
    }
    return conflicts;
}



void recurse(vector<INDICES> &arr, unordered_map< int, unordered_set<int> >::iterator &it, unordered_map< int, unordered_set<int> >::iterator &end, vector<NODE> &nodes, int runningTotal, int leastBubbles) {
    if (it == end) {
        NODE node;
        node.counts.resize(ARRS);
        for (int i = 0; i < ARRS; ++i) {
            node.counts[i] = arr[i].count;
        }
        node.total = runningTotal;
        nodes.push_back(node);
    }
    else {
        for (auto it2 = it->second.begin(); it2 != it->second.end(); ++it2) {
            ++arr[*it2].count;
            if (runningTotal - arr[*it2].count > leastBubbles) {
                --arr[*it2].count;
                return;
            }
            auto itCopy = it;
            recurse(arr, ++itCopy, end, nodes, runningTotal, leastBubbles);
            --arr[*it2].count;
        }
    }
}



void prevValue(vector< vector<int> > &indexArray) {
    int counter = 0;

    vector< vector<int> > bubbles;
    for (int i = 0; i < ARRS; ++i) {
        vector<int> temp;
        bubbles.push_back(temp);
    }
    
    vector<INDICES> arr;
    arr.resize(ARRS);
    for (int i = 0; i < ARRS; ++i) {
        arr[i].count = 0;
    }

    for (int i = 0; i < 1+((ARRS-1)/256); ++i) {

        while (true) {

            bool isFinished = true;
            for (int j = 0; j < min(256, ARRS); ++j) {
                if (arr[i*256+j].count < ARR_SIZE) {
                    isFinished = false;
                }
            }

            if (isFinished) {
                break;
            }
    
            ++counter;

            unordered_map< int, unordered_set<int> > conflicts = detectConflicts(arr, indexArray, i);
            vector<int> minInConflict;

            for (int j = 0; j < min(256, ARRS); ++j) {
                ++arr[i*256+j].count;
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

            for (int j = 0; j < minInConflict.size(); ++j) {
                ++arr[minInConflict[j]].count;
                bubbles[minInConflict[j]].pop_back();
            }
        }

    }

    cout << "Old number of cycles: " << counter << endl;

    unordered_map<int, int> bubbleData;
    int totalBubbles = 0;
    for (int i = 0; i < bubbles.size(); ++i) {
        for (int j = 0; j < bubbles[i].size(); ++j) {
            ++totalBubbles;
            int bubblesInARow = 0;
            for (int k = j; k < bubbles[i].size(); ++k) {
                if (bubbles[i][j] == bubbles[i][k] && k != bubbles[i].size()-1) {
                    ++bubblesInARow;
                }
                else if (bubbles[i][j] == bubbles[i][k] && k == bubbles[i].size()-1) {
                    ++bubblesInARow;
                    if (bubbleData.find(bubblesInARow) != bubbleData.end()) {
                        ++bubbleData[bubblesInARow];
                    }
                    else {
                        bubbleData[bubblesInARow] = 1;
                    }
                }
                else {
                    if (bubbleData.find(bubblesInARow) != bubbleData.end()) {
                        ++bubbleData[bubblesInARow];
                    }
                    else {
                        bubbleData[bubblesInARow] = 1;
                    }
                    break;
                }
            }
        }
    }

    vector<int> orderedBubbleData;
    int mostBubbles = 0;
    for (auto it = bubbleData.begin(); it != bubbleData.end(); ++it) {
        if (it->first > mostBubbles) {
            mostBubbles = it->first;
        }
    }
    for (int i = 1; i <= mostBubbles; ++i) {
        if (bubbleData.find(i) == bubbleData.end()) {
            orderedBubbleData.push_back(0);
        }
        else {
            orderedBubbleData.push_back(bubbleData[i]);
        }
    }
    for (int i = 0; i < orderedBubbleData.size(); ++i) {
        //cout << i+1 << " bubbles in a row: " << (double)orderedBubbleData[i] / (double)totalBubbles << endl;
    }
    //cout << endl << endl;

    ofstream outputFile;
    outputFile.open("test.txt");
    for (int i = 0; i < bubbles.size(); ++i) {
        for (int j = 0; j < bubbles[i].size(); ++j) {
            outputFile << bubbles[i][j] << " ";
        }
        outputFile << "\n";
    }
    outputFile.close();
}



void reorder(vector< vector <int> > &indexArray) {
    vector< vector< vector<int> > > newIndexArray;
    for (int i = 0; i < ARRS; ++i) {
        vector< vector<int> > temp;
        newIndexArray.push_back(temp);
    }

    ifstream input;
    input.open(FILENAME);
    for (int i = 0; i < ARRS; ++i) {
        string line;
        stringstream ss;
        vector<int> temp2;
        newIndexArray[i].push_back(temp2);
        getline(input, line);
        ss.str(line);
        int temp3;
        while(ss >> temp3) {
            if (temp3 == -1) {
                vector<int> temp4;
                newIndexArray[i].push_back(temp4);
            }
            else {
                newIndexArray[i].back().push_back(temp3);
            }
        }
    }
    input.close();

    // Divide values into a vector of vectors of vectors by row, then by weights
    for (int i = 0; i < 1+((ARRS-1)/256); ++i) {
        // for (int j = 0; j < min(256, ARRS); ++j) {
        //     vector<int> temp;
        //     temp.push_back(indexArray[i*256+j][0]);
        //     newIndexArray[i*256+j].push_back(temp);
        //     for (int k = 1; k < ARR_SIZE; ++k) {
        //         if (indexArray[i*256+j][k] < indexArray[i*256+j][k-1]) {
        //             vector<int> temp2;
        //             newIndexArray[i*256+j].push_back(temp2);
        //         }
        //         newIndexArray[i*256+j].back().push_back(indexArray[i*256+j][k]);
        //     }
        // }

        for (int j = 0; j < ARR_SIZE; ++j) {
            unordered_set<int> seenIndicesCol;
            for (int k = 0; k < min(256, ARRS); ++k) {
                bool noCol = false;
                if (newIndexArray[i*256+k].front().empty()) {
                    newIndexArray[i*256+k].erase(newIndexArray[i*256+k].begin());
                }
                for (auto it = newIndexArray[i*256+k].front().begin(); it != newIndexArray[i*256+k].front().end(); ++it) {
                    if (seenIndicesCol.find(*it) == seenIndicesCol.end()) {
                        indexArray[i*256+k][j] = *it;
                        newIndexArray[i*256+k].front().erase(it);
                        noCol = true;
                        break;
                    }
                }
                if (!noCol) {
                    auto it = newIndexArray[i*256+k].front().begin();
                    indexArray[i*256+k][j] = *it;
                    newIndexArray[i*256+k].front().erase(it);
                }
                seenIndicesCol.insert(indexArray[i*256+k][j]);
            }
        }
    }

    //Calculate deltas
    int deltaCount = 0;
    int deltaCount2 = 0;
    int count = 0;
    for (int i = 0; i < ARRS; ++i) {
        for (int j = 1; j < ARR_SIZE; ++j) {
            if ((indexArray[i][j] - indexArray[i][j-1] <= 16) && (indexArray[i][j] - indexArray[i][j-1] > 0)) {
                ++deltaCount;
            }
            if ((indexArray[i][j] - indexArray[i][j-1] <= 8) && (indexArray[i][j] - indexArray[i][j-1] > 0)) {
                ++deltaCount2;
            }
            ++count;
        }
    }
    double fraction = (double)deltaCount / (double)count;
    cout << "Fraction of values that can be represented as 4-bit deltas: " << fraction << endl;
    double fraction2 = (double)deltaCount2 / (double)count;
    cout << "Fraction of values that can be represented as 3-bit deltas: " << fraction2 << endl;
}