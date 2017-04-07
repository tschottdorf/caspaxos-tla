------------------------------ MODULE CASPaxos ------------------------------
(***************************************************************************
This is an interesting extension of the Single-decree Paxos algorithm
to a compare-and-swap type register.  The algorithm is very similar to
Paxos, but before starting the ACCEPT phase, proposers are free to
mutate the value.  The result is that the Paxos instance turns from a
write-once register into a reusable register with atomic semantics, for
example a compare-and-swap register.
 ***************************************************************************)
EXTENDS Integers, FiniteSets

(***************************************************************************
The data one has to define for the model.  In this case, a set of
possible Values, a set of acceptors, and a mutator which maps a ballot
number and a value to a new value.

The Mutator is a good approximation of how compare-and-swap'ping
proposers would choose the new values, abstracting away nondeterminism
by using the ballot number to decide on the new value.

For model checking, infinite sets must be avoided.  For convenience, we
more or less explicitly assume that values can be compared.
 ***************************************************************************)
CONSTANT Values, Acceptors, Mutator(_, _)

(***************************************************************************
The set of quorums.  We automatically construct this by taking all the
subsets of Acceptors which are majorities, i.e.  larger in number than
the unchosen ones.  This is for convenience; any definition for which
QuorumAssumption below holds is valid.
 ***************************************************************************)
Quorums == { S \in SUBSET(Acceptors) : Cardinality(S) > Cardinality(Acceptors \ S) }

(***************************************************************************
The register in this algorithm can repeatedly change its value.  For
simplicity, we don't let it start from "no value" but explicitly
specify a first value here.  Choosing the smallest value is reasonable,
but you can change this however you like.
 ***************************************************************************)
InitialValue == CHOOSE v \in Values : \A vv \in Values : v \leq vv

(***************************************************************************
Sanity check that our defined quorums all have nontrivial pair-wise
intersections.  This is pretty clear with the above definition of
Quorums, but note that you could specify any set of quorums (even
minorities) and the algorithm should work the same way, as long as
QuorumAssumption holds.
 ***************************************************************************)
ASSUME QuorumAssumption == /\ \A Q \in Quorums : Q \subseteq Acceptors
                           /\ \A Q1, Q2 \in Quorums : Q1 \cap Q2 # {}

(***************************************************************************
Ballot numbers are natural numbers, but it's good to have an alias so
that you know when you're talking about ballots.
 ***************************************************************************)
Ballot  == Nat
(***************************************************************************
Now that we know what a ballot is, check that the Mutator maps
Ballots and Values to Values.
 ***************************************************************************)
ASSUME /\ \A b \in Ballot, v \in Values : Mutator(b, v) \in Values


(***************************************************************************
Define the set of all possible messages.  In this specification,
proposers are implicit.  Messages originating from them are created
"out of thin air" and not addressed to a specific acceptor.  In
practice they would be, though note that each acceptor would receive
the same "message body", and omitting the explicit recipient reduces
the state space.  Note also that messages are not explicitly rejected
but simply not reacted to.  In particular, the implicit proposer has no
notion of which ballot to try next.  The spec lets them try arbitrary
ballots instead.

A message is either a prepare request for a ballot, a prepare response,
an accept request for a ballot with a new value, or an accept response.
 ***************************************************************************)
Message ==      [type : {"prepare-req"}, bal : Ballot]
           \cup [
                 type : {"prepare-rsp"}, acc : Acceptors,
                 promised : Ballot, \* ballot for which promise is given
                 accepted : Ballot, \* ballot at which val was accepted
                 val : Values
                ]
           \cup [type : {"accept-req"}, bal : Ballot, newVal : Values]
           \cup [type : {"accept-rsp"}, acc : Acceptors, accepted : Ballot ]
-----------------------------------------------------------------------------

(***************************************************************************
<<prepared[a], accepted[a], value[a]>> is the state of acceptor a: The
ballot for which a promise has been made (i.e.  no smaller ballot's
value will be accepted); the ballot at which the last value has been
accepted; and the last accepted value.
 ***************************************************************************)
VARIABLE prepared,
         accepted,
         value

(***************************************************************************
The set of all messages sent.  In each state transition of the model, a
message which could solicit a transaction may be reacted to.  Note that
this implicitly models that a message sent may be received multiple
times, and that everything can arbitrarily reorder.
 ***************************************************************************)
VARIABLE msgs

(***************************************************************************
An invariant which checks that the variables have values which make sense.
 ***************************************************************************)
TypeOK == /\ prepared \in [ Acceptors -> Ballot ]
          /\ accepted \in [ Acceptors -> Ballot ]
          /\ value \in    [ Acceptors -> Values ]
          /\ msgs \subseteq Message

(***************************************************************************
The initial state of the model.  Note that the state here has an
initial committed value, ie the register doesn't start "empty".  This
is an inconsequential simplification.
 ***************************************************************************)
Init == /\ prepared = [ a \in Acceptors |-> 0 ]
        /\ accepted = [ a \in Acceptors |-> 0 ]
        /\ value    = [ a \in Acceptors |-> InitialValue ]
        /\ msgs = {}

(***************************************************************************
Sending a message just means adding it to the set of all messages.
 ***************************************************************************)
Send(m) == msgs' = msgs \cup {m}

(***************************************************************************
Stub actions for actually sending messages.
 ***************************************************************************)
PrepareReq(b) == FALSE
PrepareRsp(a) == FALSE
AcceptReq(b, v) == FALSE
AcceptRsp(a) == FALSE

Next == \/ \E b \in Ballot : \/ PrepareReq(b)
                             \/ \E v \in Values : AcceptReq(b, v)
        \/ \E a \in Acceptors : PrepareRsp(a) \/ AcceptRsp(a)

(***************************************************************************
Spec is the (default) entry point for the TLA+ model runner.  The below
formula is a temporal formula and means that the valid behaviors of the
specification are those which initially satisfy Init, and from each
step to the following the formula Next is satisfied, unless none of the
variables changes (which is called a "stuttering step").  The model
runner uses this to expand all possible behaviors.
 ***************************************************************************)
Spec == Init /\ [][Next]_<<prepared, accepted, value, msgs>>

DesiredProperties == TypeOK
=============================================================================
\* Modification History
\* Last modified Fri Apr 07 02:14:39 EDT 2017 by tschottdorf
\* Created Thu Apr 06 02:12:06 EDT 2017 by tschottdorf
