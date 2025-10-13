// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

/**
 * @title Storage
 * @dev Store & retrieve value in a variable
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Voting is Ownable{
using Strings for uint256;
using Strings for address;

constructor(address initialOwner) Ownable(initialOwner) {
    currentStatus = WorkflowStatus.RegisteringVoters;
    emit WorkflowStatusChange(currentStatus, currentStatus);
}
    
 enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }
struct Voter { bool isRegistered; bool hasVoted; uint votedProposalId; } 
struct Proposal { string description; uint voteCount; }
struct Winner {uint id; string description; uint voteCount;}
Winner newWinner = Winner(0, "", 0);
mapping(address=>Voter) private votants;
mapping(address=>uint) private idByAdress;
mapping(uint256=>Proposal) idProposal;
mapping(string=>uint) public proposalToId; 
mapping(uint256=>Proposal) matriceResultat;
Proposal[] tabResults;

uint256 cptWhiteList=0;
uint256 propositionsMax=0;
uint256 nbrvotants;
uint256 nbrAvote;
string propositions;
string whiteliste;
string actualsvotes;
mapping(string=>uint) private checkdoublonsProrpositions;
WorkflowStatus public currentStatus;

event VoterRegistered(address voterAddress);
event ProposalRegistered(uint votedProposalId);
event Voted (address voter, uint proposalId);
event LogMessage(string message, uint);
event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);

//================ACTIONS DE VOTING

function whitelister(address _adresse, bool _registration) public onlyOwner {
    require(currentStatus == WorkflowStatus.RegisteringVoters, "Les votants ne peuvent etre ajoutes qu'en statut 'RegisteringVoters'.");
    votants[_adresse].isRegistered = _registration;
    votants[_adresse].hasVoted = false;
    idByAdress[_adresse] = cptWhiteList;

    string memory localwhiteliste = "";
    string memory adressToString = getVotantAddressString(_adresse);
    string memory identifiant = concat(", son identifiant est :", cptWhiteList.toString());
    if(_registration == false) {
        localwhiteliste = concat(" ,voici un membre NON autorise a voter : ", adressToString);
    } else {
        nbrvotants++;
        localwhiteliste = concat(", voici un membre autorise a voter : ", adressToString);
    }
    whiteliste = concat(whiteliste, localwhiteliste);
    whiteliste = concat(whiteliste, identifiant);

    emit VoterRegistered(_adresse);
    cptWhiteList++;
    
}

function registerProposition(string memory description) public {
    require(currentStatus == WorkflowStatus.ProposalsRegistrationStarted,"Les propositions ne peuvent etre enregistrees qu'en statut 'ProposalsRegistrationStarted'.");
    require(votants[msg.sender].isRegistered == true, "vous netes pas sur la whitelist, vous ne pouvez rien proposer");
    
    uint256 idProposition = propositionsMax;
    //if(!isNotEmpty(idProposal[propositionsMax].description)) {
        if(proposalToId[description] == 0) {
        // si la proposition n'a pas déjà été faite
        //attribution au votant d'id de sa nouvelle proposition
        votants[msg.sender].votedProposalId = idProposition;
        //lien id proposition => description
        idProposal[idProposition].description = description;
        //lien description => id proposition
        proposalToId[description] = idProposition;
        emit ProposalRegistered(idProposition);
        // ajout du nouveau choix de vote dans le tableau de comptage
        Proposal memory choixDeVote = Proposal("description", 0);
        tabResults.push(choixDeVote);
        propositionsMax++;
        emit LogMessage("Votre proposition est totalement nouvelle", idProposition);
        
    } else {
        // la proposition existe deja on attribue l'id déjà existant
        // attribution d'un id de vote existant au proposeur
        uint256 existingChoiceId = proposalToId[description];
        votants[msg.sender].votedProposalId = existingChoiceId;
        idProposition = existingChoiceId;
        emit LogMessage("Votre proposition a deja ete proposee", idProposition);

    }

    string memory messagepropositionpart1 = concat(" // proposition numero : ", idProposition.toString());
    string memory messagepropositionpart2 = concat(messagepropositionpart1, " => ");
    string memory messagepropositionpart3 = concat(messagepropositionpart2, description);
    propositions = concat(propositions, messagepropositionpart3);
    
}

function voter(uint256 vote) public {
    require(currentStatus == WorkflowStatus.VotingSessionStarted,"Les votes ne peuvent etre enregistres qu'en statut 'VotingSessionStarted'.");
    require(votants[msg.sender].isRegistered == true, "vous netes pas sur la whitelist, vous ne pouvez pas voter");
    
    votants[msg.sender].votedProposalId = vote;
    address adressvotant = msg.sender;
    nbrAvote++;
    emit Voted (adressvotant, vote);
    constructionResultats(vote);
}

function constructionResultats(uint256 vote) private {
    tabResults[vote].voteCount++;
    
}

function getWinner() public view returns(string memory) {
    require(currentStatus == WorkflowStatus.VotesTallied,"Les resultats ne peuvent etre consultes qu'en statut 'VotesTallied'.");

    uint256 idWinner = 0;
    uint winnerVotes = 0;
    string memory descriptionWinner;

    for(uint256 i=0; i<propositionsMax; i++){
        if(tabResults[i].voteCount > idWinner) {
            winnerVotes = tabResults[i].voteCount;
            idWinner = i;
        }
    }
    descriptionWinner = tabResults[idWinner].description;
    string memory messagegagnant1 = concat("Le gagnant du Vote est :", descriptionWinner);
    string memory messagegagnant2 = concat(messagegagnant1, ", portant l'id numero : ");
    string memory messagegagnant3 = concat(messagegagnant2, idWinner.toString());
    return messagegagnant3;
}

//================CONSULTATIONS

function consulterPropositions() public view returns(string memory) {
    require(currentStatus != WorkflowStatus.RegisteringVoters && currentStatus != WorkflowStatus.ProposalsRegistrationStarted && currentStatus != WorkflowStatus.ProposalsRegistrationEnded, "Vous ne pouvez pas consulter les propositions tant que les propositions nont pas toutes ete inscrites");
    
    return propositions;
}

function consulterWhiteList() public view returns(string memory) {
    require(currentStatus != WorkflowStatus.RegisteringVoters, "Les votants ne peuvent etre consultes qu'apres la phase de d'ajouts'.");
    
    string memory totalparticipants = concat(nbrvotants.toString()," votants autorises. ");
    string memory messageNbrParticipants = concat(totalparticipants, whiteliste);
    return messageNbrParticipants;
}

function whoVotedWhat() public view returns (string memory){
    require(currentStatus == WorkflowStatus.VotesTallied,"Les resultats ne peuvent etre consultes qu'en statut 'VotesTallied'.");
    return actualsvotes;
}

//================UTILS

function concat(string memory a, string memory b) private pure returns (string memory) {
    return string(abi.encodePacked(a, b));
}

function getVotantAddressString(address _adresse) private pure returns (string memory) {
    return _adresse.toHexString();
}

function isNotEmpty(string memory _str) public pure returns (bool) {
    return bytes(_str).length > 0;
}

//================ETAPES DU VOTES

// RegisteringVoters" à "ProposalsRegistrationStarted"
function startPropositions() public onlyOwner {
    require(currentStatus == WorkflowStatus.RegisteringVoters,"Le workflow n'est pas en statut 'RegisteringVoters'.");
    emit WorkflowStatusChange(currentStatus, WorkflowStatus.ProposalsRegistrationStarted);
    currentStatus = WorkflowStatus.ProposalsRegistrationStarted;
}

// "ProposalsRegistrationStarted" à "ProposalsRegistrationEnded"
function endPropositions() public onlyOwner {
    require(currentStatus == WorkflowStatus.ProposalsRegistrationStarted,"Le workflow n'est pas en statut 'ProposalsRegistrationStarted'.");
    emit WorkflowStatusChange(currentStatus, WorkflowStatus.ProposalsRegistrationEnded);
    currentStatus = WorkflowStatus.ProposalsRegistrationEnded;
}

// "ProposalsRegistrationEnded" à "VotingSessionStarted"
function startVoting() public onlyOwner {
    require(currentStatus == WorkflowStatus.ProposalsRegistrationEnded,"Le workflow n'est pas en statut 'ProposalsRegistrationEnded'.");
    emit WorkflowStatusChange(currentStatus, WorkflowStatus.VotingSessionStarted);
    currentStatus = WorkflowStatus.VotingSessionStarted;
}

// "VotingSessionStarted" à "VotingSessionEnded"
function endVoting() public onlyOwner {
    require(currentStatus == WorkflowStatus.VotingSessionStarted,"Le workflow n'est pas en statut 'VotingSessionStarted'.");
    emit WorkflowStatusChange(currentStatus, WorkflowStatus.VotingSessionEnded);
    currentStatus = WorkflowStatus.VotingSessionEnded;
}

// "VotingSessionEnded" à "VotesTallied"
function showWinner() public onlyOwner {
    require(currentStatus == WorkflowStatus.VotingSessionEnded,"Le workflow n'est pas en statut 'VotingSessionEnded'.");
    emit WorkflowStatusChange(currentStatus, WorkflowStatus.VotesTallied);
    currentStatus = WorkflowStatus.VotesTallied;
}

// Fonction pour obtenir le statut actuel (utile pour l'interface)
function getCurrentStatus() public view returns (WorkflowStatus) {
    return currentStatus;
}
}
