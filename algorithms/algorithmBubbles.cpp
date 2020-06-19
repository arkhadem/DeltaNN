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

unordered_map< int, unordered_set<int> > detectConflicts(vector< vector< vector<int> > > &indexArray, vector< vector< int > > &currentIndex, int block);
void addBubbles(vector< vector< vector<int> > > &indexArray);
void reorder(vector< vector< vector<int> > > &indexArray);

int main(){

    srand(time(NULL));

    vector< vector< vector<int> > > indexArray;

    int block = 0;
    int rowsInBlock = 0;

    cout << "Please enter filename: ";
    string filename = "";
    cin >> filename;
    cout << "Please enter block size: ";
    int blockSize = 0;
    cin >> blockSize;

    ifstream inputFile;
    inputFile.open(filename);
    string line;
    while (getline(inputFile, line)) {

        if (rowsInBlock == 0) {
            vector< vector<int> > tempBlock;
            indexArray.push_back(tempBlock);
        }

        stringstream ss;
        vector<int> temp;
        indexArray[block].push_back(temp);
        ss.str(line);
        int ind;
        while(ss >> ind) {
            if (ind != -1) {
                indexArray[block][rowsInBlock].push_back(ind);
            }
        }
        ++rowsInBlock;
        if (rowsInBlock == blockSize) {
            ++block;
            rowsInBlock = 0;
        }
    }
    inputFile.close();

    cout << "Blocks: " << indexArray.size() << ", Rows: " << indexArray[0].size() << ", Row length: " << indexArray[0][0].size() << endl << endl;

    addBubbles(indexArray);
}



unordered_map< int, unordered_set<int> > detectConflicts(vector< vector< vector<int> > > &indexArray, vector< vector< int > > &currentIndex, int block) {
    unordered_map< int, unordered_set<int> > conflicts;
    for (int j = 0; j < indexArray[block].size(); ++j) {
        for (int k = j+1; k < indexArray[block].size(); ++k) {
            if ((indexArray[block][j][currentIndex[block][j]] == indexArray[block][k][currentIndex[block][k]]) && 
                (currentIndex[block][j] < indexArray[block][j].size()) && (currentIndex[block][k] < indexArray[block][k].size())) {
                if (conflicts.find(indexArray[block][j][currentIndex[block][j]]) != conflicts.end()) {
                    conflicts[indexArray[block][j][currentIndex[block][j]]].insert(j);
                    conflicts[indexArray[block][j][currentIndex[block][j]]].insert(k);
                }
                else {
                    unordered_set<int> temp;
                    temp.insert(j);
                    temp.insert(k);
                    conflicts[indexArray[block][j][currentIndex[block][j]]] = temp;
                }
            }
        }
    }
    return conflicts;
}



void addBubbles(vector< vector< vector<int> > > &indexArray) {
    vector< vector<int> > currentIndex;
    vector< vector< vector<int> > > indexArrayWithBubbles;
    for (int i = 0; i < indexArray.size(); ++i) {
        vector<int> temp;
        currentIndex.push_back(temp);
        for(int j = 0; j < indexArray[i].size(); ++j) {
            currentIndex[i].push_back(0);
        }
    }

    indexArrayWithBubbles.resize(indexArray.size());
    for (int i = 0; i < indexArrayWithBubbles.size(); ++i) {
        indexArrayWithBubbles[i].resize(indexArray[i].size());
    }

    for (int i = 0; i < indexArray.size(); ++i) {
        while (true) {
            bool isFinished = true;
            for (int j = 0; j < indexArray[i].size(); ++j) {
                if (currentIndex[i][j] < indexArray[i][j].size()) {
                    isFinished = false;
                }
            }

            if (isFinished) {
                break;
            }

            unordered_map< int, unordered_set<int> > conflicts = detectConflicts(indexArray, currentIndex, i);
            unordered_set<int> rowsWithConflicts;

            for (auto it = conflicts.begin(); it != conflicts.end(); ++it) {
                int min = 10000000;
                int minIndex = -1;
                for (auto it2 = it->second.begin(); it2 != it->second.end(); ++it2) {
                    if (currentIndex[i][*it2] < min) {
                        min = indexArray[i][*it2][currentIndex[i][*it2]];
                        minIndex = *it2;
                    }
                    rowsWithConflicts.insert(*it2);
                }
                rowsWithConflicts.erase(minIndex);
            }
            for (int j = 0; j < indexArray[i].size(); ++j) {
                if ((rowsWithConflicts.find(j) == rowsWithConflicts.end()) && (currentIndex[i][j] < indexArray[i][j].size())) {
                    indexArrayWithBubbles[i][j].push_back(indexArray[i][j][currentIndex[i][j]]);
                    ++currentIndex[i][j];
                }
                else {
                    indexArrayWithBubbles[i][j].push_back(-1);
                }
            }
            for (int j = 0; j < indexArray[i].size(); ++j) {
                if (currentIndex[i][j] < indexArray[i][j].size()) {
                    ++currentIndex[i][j];
                }
            }    
        }
    }

    ofstream outputFile;
    outputFile.open("test.txt");
    for (int i = 0; i < indexArrayWithBubbles.size(); ++i) {
        for (int j = 0; j < indexArrayWithBubbles[i].size(); ++j) {
            for (int k = 0; k < indexArrayWithBubbles[i][j].size(); ++k) {
                outputFile << indexArrayWithBubbles[i][j][k] << " ";
            }
            outputFile << "\n";
        }
    }
    outputFile.close();
    
    int totalValues = 0;
    int numberBubbles = 0;
    int number3BitDeltas = 0;
    int number3BitNonDeltas = 0;
    int number4BitDeltas = 0;
    int number4BitNonDeltas = 0;
    int lastValue = 0;

    for (int i = 0; i < indexArrayWithBubbles.size(); ++i) {
        for (int j = 0; j < indexArrayWithBubbles[i].size(); ++j) {
            for (int k = 0; k < indexArrayWithBubbles[i][j].size(); ++k) {
                if ((indexArrayWithBubbles[i][j][k] != -1) && (indexArrayWithBubbles[i][j][k] - lastValue < 8) && (indexArrayWithBubbles[i][j][k] - lastValue >= 0)) {
                    ++number3BitDeltas;
                }
                else if ((indexArrayWithBubbles[i][j][k] != -1) && !((indexArrayWithBubbles[i][j][k] - lastValue < 8) && (indexArrayWithBubbles[i][j][k] - lastValue >= 0))) {
                    ++number3BitNonDeltas;
                }
                if ((indexArrayWithBubbles[i][j][k] != -1) && (indexArrayWithBubbles[i][j][k] - lastValue < 16) && (indexArrayWithBubbles[i][j][k] - lastValue >= 0)) {
                    ++number4BitDeltas;
                }
                else if ((indexArrayWithBubbles[i][j][k] != -1) && !((indexArrayWithBubbles[i][j][k] - lastValue < 16) && (indexArrayWithBubbles[i][j][k] - lastValue >= 0))) {
                    ++number4BitNonDeltas;
                }
                if (indexArrayWithBubbles[i][j][k] == -1) {
                    ++numberBubbles;
                }
                else {
                    lastValue = indexArrayWithBubbles[i][j][k];
                }
                ++totalValues;
            }
            lastValue = 0;
        }
    }
    cout << "% of cycles that are bubbles: " << (double)numberBubbles / (double)totalValues << endl;
    cout << "% of cycles that can be represented as 3 bit deltas: " << (double)number3BitDeltas / (double)totalValues << endl;
    cout << "% of cycles that can't be represented as 3 bit deltas: " << (double)number3BitNonDeltas / (double)totalValues << endl;
    cout << "% of cycles that can be represented as 4 bit deltas: " << (double)number4BitDeltas / (double)totalValues << endl;
    cout << "% of cycles that can't be represented as 4 bit deltas: " << (double)number4BitNonDeltas / (double)totalValues << endl;
}



// void reorder(vector< vector <int> > &indexArray) {
//     vector< vector< vector<int> > > newIndexArray;
//     for (int i = 0; i < ARRS; ++i) {
//         vector< vector<int> > temp;
//         newIndexArray.push_back(temp);
//     }

//     ifstream input;
//     input.open(FILENAME);
//     for (int i = 0; i < ARRS; ++i) {
//         string line;
//         stringstream ss;
//         vector<int> temp2;
//         newIndexArray[i].push_back(temp2);
//         getline(input, line);
//         ss.str(line);
//         int temp3;
//         while(ss >> temp3) {
//             if (temp3 == -1) {
//                 vector<int> temp4;
//                 newIndexArray[i].push_back(temp4);
//             }
//             else {
//                 newIndexArray[i].back().push_back(temp3);
//             }
//         }
//     }
//     input.close();

//     // Divide values into a vector of vectors of vectors by row, then by weights
//     for (int i = 0; i < 1+((ARRS-1)/256); ++i) {
//         // for (int j = 0; j < min(256, ARRS); ++j) {
//         //     vector<int> temp;
//         //     temp.push_back(indexArray[i*256+j][0]);
//         //     newIndexArray[i*256+j].push_back(temp);
//         //     for (int k = 1; k < ARR_SIZE; ++k) {
//         //         if (indexArray[i*256+j][k] < indexArray[i*256+j][k-1]) {
//         //             vector<int> temp2;
//         //             newIndexArray[i*256+j].push_back(temp2);
//         //         }
//         //         newIndexArray[i*256+j].back().push_back(indexArray[i*256+j][k]);
//         //     }
//         // }

//         for (int j = 0; j < ARR_SIZE; ++j) {
//             unordered_set<int> seenIndicesCol;
//             for (int k = 0; k < min(256, ARRS); ++k) {
//                 bool noCol = false;
//                 if (newIndexArray[i*256+k].front().empty()) {
//                     newIndexArray[i*256+k].erase(newIndexArray[i*256+k].begin());
//                 }
//                 for (auto it = newIndexArray[i*256+k].front().begin(); it != newIndexArray[i*256+k].front().end(); ++it) {
//                     if (seenIndicesCol.find(*it) == seenIndicesCol.end()) {
//                         indexArray[i*256+k][j] = *it;
//                         newIndexArray[i*256+k].front().erase(it);
//                         noCol = true;
//                         break;
//                     }
//                 }
//                 if (!noCol) {
//                     auto it = newIndexArray[i*256+k].front().begin();
//                     indexArray[i*256+k][j] = *it;
//                     newIndexArray[i*256+k].front().erase(it);
//                 }
//                 seenIndicesCol.insert(indexArray[i*256+k][j]);
//             }
//         }
//     }

//     //Calculate deltas
//     int deltaCount = 0;
//     int deltaCount2 = 0;
//     int count = 0;
//     for (int i = 0; i < ARRS; ++i) {
//         for (int j = 1; j < ARR_SIZE; ++j) {
//             if ((indexArray[i][j] - indexArray[i][j-1] <= 16) && (indexArray[i][j] - indexArray[i][j-1] > 0)) {
//                 ++deltaCount;
//             }
//             if ((indexArray[i][j] - indexArray[i][j-1] <= 8) && (indexArray[i][j] - indexArray[i][j-1] > 0)) {
//                 ++deltaCount2;
//             }
//             ++count;
//         }
//     }
//     double fraction = (double)deltaCount / (double)count;
//     cout << "Fraction of values that can be represented as 4-bit deltas: " << fraction << endl;
//     double fraction2 = (double)deltaCount2 / (double)count;
//     cout << "Fraction of values that can be represented as 3-bit deltas: " << fraction2 << endl;
// }