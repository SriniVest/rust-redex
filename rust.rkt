;; -*- coding: utf-8; -*-

;; Cheat sheet for unicode, using M-x set-input-method as TeX:
;; \alpha -> α
;; \beta  -> β
;; \gamma -> γ
;; \cdot  -> ·
;; \ell   -> ℓ
;; \in    -> ∈
;; \notin -> ∉
;; and so on
;; lifetime-≤

#lang racket

(require redex
         rackunit)

(define-language Patina
  (prog (srs fns))
  ;; structures:
  (srs (sr ...))
  (sr (struct s ℓs (ty ...)))
  ;; lifetimes:
  (ℓs (ℓ ...))
  ;; function def'ns
  (fns (fn ...))
  (fn (fun g ℓs vdecls bk))
  ;; blocks:
  (bk (block ℓ vdecls sts))
  ;; variable decls
  (vdecls [vdecl ...])
  (vdecl (x ty))
  ;; statements:
  [sts (st ...)]
  (st (lv = rv)
      (lv := rv)
      (free lv)                    ;; drop all memory owned by `lv`
      (call g ℓs lvs)
      (match lv (Some mode x => bk) (None => bk))
      bk)
  ;; lvalues :
  ;; changing "field names" to be numbers
  (lvs (lv ...))
  (lv x                            ;; variable
      (lv · f)                     ;; field projection
      (lv @ lv)                    ;; indexing
      (* lv))                      ;; deref
  ;; rvalues :
  (rv lv                           ;; move lvalue
      (copy lv)                    ;; copy POD lvalue
      (& ℓ mq lv)                  ;; take address of lvalue
      (struct s ℓs (lv ...))       ;; struct constant
      (new lv)                     ;; allocate memory
      number                       ;; constant number
      (lv + lv)                    ;; sum
      (Some lv)                    ;; create an Option with Some
      (None ty)                    ;; create an Option with None
      (vec ty lv ...)              ;; create a fixed-length vector
      (vec-len lv)                 ;; extract length of a vector
      (pack lv ty)                 ;; convert fixed-length to DST
      )
  (mode (ref mq) move)
  ;; types : 
  (tys (ty ...))
  (ty (struct s ℓs)             ;; s<'ℓ...>
      (~ ty)                       ;; ~t
      (& ℓ mq ty)                  ;; &'ℓ mq t
      int
      (Option ty)
      (vec ty olen))
  ;; mq : mutability qualifier
  (mq mut imm)
  (mqs [mq ...])
  ;; variables
  (x variable-not-otherwise-mentioned)
  ;; function names
  (g variable-not-otherwise-mentioned)
  ;; structure names
  (s variable-not-otherwise-mentioned)
  ;; labels
  (ℓ variable-not-otherwise-mentioned)
  ;; field "names"
  (f number)
  ;; z -- sizes, offsets
  [zs (z ...)]
  [z number]
  ;; l -- vector lengths
  [l number]
  ;; olen -- optional vector lengths
  [olen number erased]
  ;; hack for debugging
  (debug debug-me)
  )

(check-not-false (redex-match Patina ty (term (vec int 3))))

;;;;
;;
;; EVALUATION
;;
;;;;

(define-extended-language Patina-machine Patina
  ;; a configuration of the machine
  [C (prog H V T S)]
  ;; H (heap) : maps addresses to heap values
  [H ((α hv) ...)]
  ;; hv (heap values)
  [hv (ptr α) (int number) void]
  ;; V: maps variable names to addresses
  [V (vmap ...)]
  [vmap ((x α) ...)]
  ;; T : a map from names to types
  [T (vdecls ...)]
  ;; S (stack) : stack-frames contain pending statements
  [S (sf ...)]
  [sf (ℓ sts)]
  [(αs βs γs) (number ...)]
  [(α β γ) number]
  )

;; unit test setup for helper fns

(define test-srs
  (term [(struct A () (int))
         (struct B (l0) (int (& l0 mut int)))
         (struct C (l0) ((struct A ())
                         (struct B (l0))))
         (struct D (l0) ((struct C (l0))
                         (struct A ())
                         (struct C (l0))
                         (struct B (l0))))
         (struct E () ((~ int)))
         ]))

(check-not-false (redex-match Patina-machine srs test-srs))

(define test-T (term [[(i int)
                       (p (~ int))]
                      [(a (struct A ()))
                       (b (struct B (static)))
                       (c (struct C (static)))
                       (q (& b1 imm int))
                       (r (~ int))
                       (s (Option (~ int)))
                       (ints3 (vec int 3))
                       (i0 int)
                       (i1 int)
                       (i2 int)
                       (i3 int)
                       (ints3p (& b1 imm (vec int 3)))
                       (intsp (& b1 imm (vec int erased)))
                       ]]))
(check-not-false (redex-match Patina-machine T test-T))

(define test-V (term (((i 10)
                       (p 11))
                      ((a 12)
                       (b 13)
                       (c 15)
                       (q 18)
                       (r 19)
                       (s 20)
                       (ints3 22)
                       (i0 25)
                       (i1 26)
                       (i2 27)
                       (i3 28)
                       (ints3p 29)
                       (intsp 30)))))
(check-not-false (redex-match Patina-machine V test-V))

(define test-H (term [(10 (int 22)) ;; i == 22
                      (11 (ptr 99)) ;; p == 99
                      (12 (int 23)) ;; a:0
                      (13 (int 24)) ;; b:0
                      (14 (ptr 98)) ;; b:1
                      (15 (int 25)) ;; c:1:0
                      (16 (int 26)) ;; c:1:0
                      (17 (ptr 97)) ;; c:1:1
                      (18 (ptr 98)) ;; q
                      (19 (ptr 96)) ;; r
                      (20 (int 1))  ;; s – discriminant
                      (21 (ptr 95)) ;; s – payload
                      (22 (int 10)) ;; ints3 @ 0
                      (23 (int 11)) ;; ints3 @ 1
                      (24 (int 12)) ;; ints3 @ 2
                      (25 (int 0))  ;; i0
                      (26 (int 1))  ;; i1
                      (27 (int 2))  ;; i2
                      (28 (int 3))  ;; i3
                      (29 (ptr 22)) ;; ints3p
                      (30 (ptr 22)) ;; intsp ptr
                      (31 (int 3))  ;; intsp dst
                      (95 (int 31))   ;; *payload(s)
                      (96 (int 30))   ;; *c:1:1
                      (97 (int 29))   ;; *c:1:1
                      (98 (int 28))   ;; *b:1
                      (99 (int 27))])) ;; *p
(check-not-false (redex-match Patina-machine H test-H))

(define test-dst-srs
  (term [(struct RCDataInt3 () [int (vec int 3)])
         (struct RCInt3 (l0) [(& l0 imm (struct RCDataInt3 []))])
         (struct RCDataIntN () (int (vec int erased)))
         (struct RCIntN (l0) [(& l0 imm (struct RCDataIntN []))])
         (struct Cycle1 () [(Option (~ (struct Cycle []))) (vec int erased)])
         (struct Cycle2 () [(Option (~ (struct Cycle [])))])
         ]))

(check-not-false (redex-match Patina-machine srs test-dst-srs))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; simple test prog that assigns to the result pointer

(define twentytwo-main
  (term (fun main [a] [(outp (& a mut int))]
             (block l0 [] [((* outp) = 22)]))))

(check-not-false (redex-match Patina-machine fn twentytwo-main))

(define twentytwo-fns (term [,twentytwo-main]))
(check-not-false (redex-match Patina-machine fns twentytwo-fns))

(define twentytwo-prog
  (term (,test-srs ,twentytwo-fns)))
(check-not-false (redex-match Patina-machine prog twentytwo-prog))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; test prog that creates a linked list and counts down

(define sum-srs
  (term [(struct List () (int
                          (Option (~ (struct List [])))))]))
(check-not-false (redex-match Patina-machine srs sum-srs))

(define sum-main
  (term (fun main [a] [(outp (& a mut int))]
             (block l0 [(i int)
                        (n (Option (~ (struct List []))))
                        (s (struct List []))
                        (l (~ (struct List [])))
                        (p (& l0 imm (struct List [])))]
                    [(i = 22)
                     (n = (None (~ (struct List []))))
                     (s = (struct List [] (i n)))
                     (l = (new s))
                     (i = 44)
                     (n = (Some l))
                     (s = (struct List [] (i n)))
                     (l = (new s))
                     (p = (& l0 imm (* l)))
                     (call sum_list [l0 a] [p outp])]))))
(check-not-false (redex-match Patina-machine fn sum-main))

;; fn sum_list(inp: &List, outp: &mut int) {
;;     let r: int = inp.0;
;;     match inp.1 {
;;         Some(ref next1) => { // next1: &~List
;;             let next2 = &**next1;
;;             let b = 0;
;;             {
;;                 let c = &mut b;
;;                 sum_list(next2, c);
;;             }
;;             *outp = r + b;
;;         }
;;         None => {
;;             *outp = r + b;
;;         }
;;     }
;; }
(define sum-sum_list
  (term (fun sum_list [a b] [(inp (& a imm (struct List [])))
                             (outp (& b mut int))]
             (block l0
                    [(r int)]
                    [(r = (copy ((* inp) · 0)))
                     (match ((* inp) · 1)
                       (Some (ref imm) next1 =>
                             (block l1 [(next2 (& l1 imm (struct List [])))
                                        (b int)]
                                    [(next2 = (& l1 imm (* (* next1))))
                                     (b = 0)
                                     (block l2 [(c (& l1 mut int))]
                                            [(c = (& l2 mut b))
                                             (call sum_list [l1 l2] [next2 c])
                                             ((* outp) = (r + b))])]))
                       (None =>
                             (block l2 []
                                    [((* outp) = (copy r))])))]))))
(check-not-false (redex-match Patina-machine fn sum-sum_list))

(define sum-fns
  (term (,sum-main ,sum-sum_list)))

(define sum-prog
  (term (,sum-srs ,sum-fns)))
(check-not-false (redex-match Patina-machine prog sum-prog))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; test prog that creates an RC vector, casts it to DST, and then
;; accesses it

(define dst-srs
  (term [(struct RCDataInt3 () [int (vec int 3)])
         (struct RCInt3 (l0) [(& l0 imm (struct RCDataInt3 []))])
         (struct RCDataIntN () (int (vec int erased)))
         (struct RCIntN (l0) [(& l0 imm (struct RCDataIntN []))])
         ]))

;; gonna be super tedious...
(define dst-main
  (term (fun main [a] [(outp (& a mut int))]
             (block l0 [(i1 int)
                        (i2 int)
                        (i3 int)
                        (v (vec int 3))
                        (rd3 (struct RCDataInt3 []))
                        (rd3p (& l0 imm (struct RCDataInt3 [])))
                        (rdNp (& l0 imm (struct RCDataIntN [])))
                        ]
                    [(i1 = 22)
                     (i2 = 23)
                     (i3 = 24)
                     (v = (vec int i1 i2 i3))
                     (i1 = 1)
                     (rd3 = (struct RCDataInt3 [] (i1 v)))
                     (rd3p = (& l0 imm rd3))
                     (rdNp = (pack rd3p (& l0 imm (struct RCDataIntN []))))
                     (i1 = 0)
                     (i2 = 0)
                     (i2 = ((((* rdNp) · 1) @ i1) + i2))
                     (i1 = 1)
                     (i2 = ((((* rdNp) · 1) @ i1) + i2))
                     (i1 = 2)
                     (i2 = ((((* rdNp) · 1) @ i1) + i2))
                     ((* outp) = (copy i2))
                     ]))))
(check-not-false (redex-match Patina-machine fn dst-main))

(define dst-prog
  (term (,dst-srs [,dst-main])))
(check-not-false (redex-match Patina-machine prog dst-prog))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; initial -- the initial state of the machine

(define initial-H (term [(0 (int 0))       ;; static value for result code
                         (1 (ptr 0))]))    ;; pointer to result code
(check-not-false (redex-match Patina-machine H initial-H))

(define initial-V (term [[(resultp 1)]]))
(check-not-false (redex-match Patina-machine V initial-V))

(define initial-T (term [[(resultp (& l0 mut int))]]))
(check-not-false (redex-match Patina-machine T initial-T))

(define initial-S (term [(l0 [(call main (l0) (resultp))])]))
(check-not-false (redex-match Patina-machine S initial-S))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ∈, ∉ -- a metafunction like member

(define-metafunction Patina-machine
  ∈ : any [any ...] -> any

  [(∈ any_0 [any_1 ...])
   ,(not (not (member (term any_0) (term [any_1 ...]))))])

(define-metafunction Patina-machine
  ∉ : any [any ...] -> any

  [(∉ any_0 [any_1 ...])
   ,(not (member (term any_0) (term [any_1 ...])))])

(test-equal (term (∈ 1 [1 2 3])) (term #t))
(test-equal (term (∈ 4 [1 2 3])) (term #f))
(test-equal (term (∉ 1 [1 2 3])) (term #f))
(test-equal (term (∉ 4 [1 2 3])) (term #t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; size

(define-metafunction Patina-machine
  size : [any ...] -> number

  [(size [any ...]) ,(length (term [any ...]))]
  )

(test-equal (term (size [1 2 3])) (term 3))
(test-equal (term (size [])) (term 0))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ∀, ∃ -- useful functions for operating over vectors of booleans.
;; Particularly useful in combination with macros and maps.

(define-metafunction Patina-machine
  ∀ : [any ...] -> boolean

  [(∀ []) #t]
  [(∀ [#f any ...]) #f]
  [(∀ [#t any ...]) (∀ [any ...])]
  )

(define-metafunction Patina-machine
  ∃ : [any ...] -> boolean

  [(∃ []) #f]
  [(∃ [#t any ...]) #t]
  [(∃ [#f any ...]) (∃ [any ...])]
  )

(define-metafunction Patina-machine
  ∄ : [any ...] -> boolean

  [(∄ any) (not (∃ any))]
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ≠ -- test if things are different

(define-metafunction Patina-machine
  ≠ : any any -> boolean

 [(≠ any any) #f]
 [(≠ any_0 any_1) #t]
 )

(test-equal (term (≠ x x)) (term #f))
(test-equal (term (≠ x y)) (term #t))
(test-equal (term (≠ (~ int) (~ int))) (term #f))
(test-equal (term (≠ (~ int) (~ (~ int)))) (term #t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ∪ -- a metafunction for set union

(define-metafunction Patina-machine
  ∪ : [any ...] [any ...] -> [any ...]

  [(∪ [any_0 any_1 ...] [any_2 ...])
   (∪ [any_1 ...] [any_2 ...])
   (side-condition (term (∈ any_0 [any_2 ...])))]

  [(∪ [any_0 any_1 ...] [any_2 ...])
   (∪ [any_1 ...] [any_0 any_2 ...])]

  [(∪ [] [any_1 ...])
   [any_1 ...]]

  )

(test-equal (term (∪ [1 4] [1 2 3])) (term [4 1 2 3]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ⊆ -- a metafunction for subseteq comparison

(define-metafunction Patina-machine
  ⊆ : [any ...] [any ...] -> boolean

  [(⊆ [] [any ...]) #t]

  [(⊆ [any_0 any_1 ...] [any_2 ...])
   (and (∀ [∃ any_0 [any_2 ...]])
        (⊆ [any_1 ...] [any_2 ...]))]

  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ⊎ -- a metafunction for disjoint set union

(define-metafunction Patina-machine
  ⊎ : [any ...] [any ...] -> [any ...]

  [(⊎ [any_0 ...] [any_1 ...])
   ([any_0 ...] [any_1 ...])]

  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; \\ -- a metafunction for set difference

(define-metafunction Patina-machine
  \\ : [any ...] [any ...] -> [any ...]

  [(\\ any_0 any_1)
   ,(remove* any_0 any_1)])

(test-equal (term (\\ [1 2 3] [2])) (term [1 3]))
(test-equal (term (\\ [1 2 3] [4])) (term [1 2 3]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get -- a metafunction like assoc that works on lists like '((k v) (k1 v1))

(define-metafunction Patina-machine
  get : any [(any any) ...] -> any

  [(get any_k0 [(any_k0 any_v0) (any_k1 any_v1) ...])
   any_v0]

  [(get any_k0 [(any_k1 any_v1) (any_k2 any_v2) ...])
   (get any_k0 [(any_k2 any_v2) ...])])

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get* -- search through multiple assoc lists

(define (get* key lists)
  (let ([v (assoc key (car lists))])
    (if (not v)
        (get* key (cdr lists))
        (cadr v))))

(test-equal (get* (term a) (term (((a 1) (b 2)) ((c 3)))))
            1)

(test-equal (get* (term c) (term (((a 1) (b 2)) ((c 3)))))
            3)

(test-equal (get* (term e) (term (((a 1) (b 2)) ((c 3)) ((d 4) (e 5)))))
            5)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sort-heap -- sort heap address in ascending order

(define (sort-heap heap)
  (sort heap (λ (pair1 pair2) (< (car pair1)
                                      (car pair2)))))

;; useful heap predicates

(define (in-range addr base size)
  (and (>= addr base)
       (< addr (+ base size))))

(define (select H α z)
  (let* [(matching (filter (λ (pair) (in-range (car pair) α z)) H))
         (sorted (sort-heap matching))
         (values (map cadr sorted))]
    values))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; reject – useful for debugging since it causes contract errors

(define-metafunction Patina-machine
  reject : debug -> number

  [(reject debug) 0])

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sum

(define-metafunction Patina-machine
  sum : zs -> z
  
  [(sum []) 0]
  [(sum [z_0 z_1 ...])
   ,(+ (term z_0) (term (sum [z_1 ...])))]

  )

(test-equal (term (sum [1 2 3]))
            (term 6))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; len

(define-metafunction Patina-machine
  len : [any ...] -> number
  
  [(len [any ...])
   ,(length (term [any ...]))])

(test-equal (term (len [1 2 3]))
            (term 3))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; prefix sum

(define-metafunction Patina-machine
  prefix-sum : z zs -> zs
  
  [(prefix-sum z_a ()) ()]
  [(prefix-sum z_a (z_b z_c ...))
   [z_d z_e ...]
   (where z_d (sum [z_a z_b]))
   (where [z_e ...] (prefix-sum z_d [z_c ...]))]

  )

(test-equal (term (prefix-sum 0 ()))
            (term ()))

(test-equal (term (prefix-sum 0 (1 2 3)))
            (term (1 3 6)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; offset, inc, and dec

(define-metafunction Patina-machine
  offset : α z -> α

  [(offset α z) ,(+ (term α) (term z))])

(define-metafunction Patina-machine
  inc : α -> α

  [(inc z) ,(add1 (term z))])

(define-metafunction Patina-machine
  dec : α -> α

  [(dec z) ,(sub1 (term z))])

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; deref function -- search a heap for a given address.

(define-metafunction Patina-machine
  deref : H α -> hv

  [(deref H α)
   (get α H)])

(test-equal (term (deref [(1 (ptr 22))] 1)) (term (ptr 22)))
(test-equal (term (deref [(2 (ptr 23)) (1 (int 22))] 1)) (term (int 22)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; fun-defn -- 

(define-metafunction Patina-machine
  fun-defn : fns g -> fn
  
  [(fun-defn (fn_0 fn_1 ...) g)
   fn_0
   (where (fun g ℓs ((x ty) ...) bk) fn_0)]

  [(fun-defn (fn_0 fn_1 ...) g)
   (fun-defn (fn_1 ...) g)])

(test-equal (term (fun-defn ,twentytwo-fns main))
            (term ,twentytwo-main))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; update -- replaces value for α

(define-metafunction Patina-machine
  update : H α hv -> H
  
  [(update ((α_0 hv_0) (α_1 hv_1) ...) α_0 hv_2)
   ((α_0 hv_2) (α_1 hv_1) ...)]

  [(update ((α_0 hv_0) (α_1 hv_1) ...) α_2 hv_2)
   ,(append (term ((α_0 hv_0))) (term (update ((α_1 hv_1) ...) α_2 hv_2)))])

(test-equal (term (update [(2 (ptr 23)) (1 (int 22))] 1 (int 23)))
            (term ((2 (ptr 23)) (1 (int 23)))))

(test-equal (term (update [(2 (ptr 23)) (1 (int 22))] 2 (int 23)))
            (term ((2 (int 23)) (1 (int 22)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; extend -- grows a heap with z contiguous new addresses 

(define-metafunction Patina-machine
  extend : H α z -> H
  
  [(extend H α 0) H]

  [(extend ((β hv) ...) α z)
   (extend ((α void) (β hv) ...)
            ,(add1 (term α))
            ,(sub1 (term z)))])

(test-equal (term (extend [(10 (ptr 1))
                           (11 (int 2))
                           (12 (ptr 3))]
                           13
                           3))
            (term [(15 void)
                   (14 void)
                   (13 void)
                   (10 (ptr 1))
                   (11 (int 2))
                   (12 (ptr 3))]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; shrink -- removes z contiguous addresses from domain of heap

(define-metafunction Patina-machine
  shrink : H α z -> H
  
  [(shrink H α z)
   ,(filter (λ (pair) (not (in-range (car pair) (term α) (term z))))
            (term H))])

(test-equal (term (shrink [(10 (ptr 1))
                           (11 (int 2))
                           (12 (ptr 3))
                           (13 (ptr 4))
                           (14 (ptr 5))]
                           11
                           3))
            (term [(10 (ptr 1))
                   (14 (ptr 5))]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; is-void -- test for void

(define-metafunction Patina-machine
  is-void : hv -> boolean

  [(is-void void) #t]
  [(is-void (ptr α)) #f]
  [(is-void (int number)) #f])

(test-equal (term (is-void (ptr 2))) #f)
(test-equal (term (is-void void)) #t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; field-tys

(define-metafunction Patina-machine
  field-tys : srs s ℓs -> (ty ...)
  
  [(field-tys ((struct s_0 (ℓ_0 ...) (ty_0 ...)) sr ...) s_0 ℓs_1)
   (ty_0 ...)] ;; FIXME subst lifetimes

  [(field-tys ((struct s_0 (ℓ_0 ...) (ty_0 ...)) sr ...) s_1 ℓs_1)
   (field-tys (sr ...) s_1 ℓs_1)])

(test-equal (term (field-tys ,test-srs A ()))
            (term (int)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; is-DST

(define-metafunction Patina-machine
  is-DST : srs ty -> boolean

  [(is-DST srs ty) (is-DST-1 [] srs ty)])

(define-metafunction Patina-machine
  is-DST-1 : [s ...] srs ty -> boolean

  [(is-DST-1 [s_a ...] srs (struct s ℓs))
   #false
   (side-condition (member (term s) (term [s_a ...])))]
  [(is-DST-1 [s_a ...] srs (struct s ℓs))
   (is-DST-1 [s s_a ...] srs ty_z)
   (where (ty_a ... ty_z) (field-tys srs s ℓs))]
  [(is-DST-1 [s ...] srs (~ ty)) #false]
  [(is-DST-1 [s ...] srs (& ℓ mq ty)) #false]
  [(is-DST-1 [s ...] srs int) #false]
  [(is-DST-1 [s ...] srs (Option ty)) (is-DST-1 [s ...] srs ty)]
  [(is-DST-1 [s ...] srs (vec ty erased)) #true]
  [(is-DST-1 [s ...] srs (vec ty l)) #false])

(test-equal (term (is-DST ,test-dst-srs (~ (vec int erased))))
            #false)

(test-equal (term (is-DST ,test-dst-srs (vec int erased)))
            #true)

(test-equal (term (is-DST ,test-dst-srs (struct RCDataInt3 [])))
            #false)

(test-equal (term (is-DST ,test-dst-srs (struct RCInt3 [])))
            #false)

(test-equal (term (is-DST ,test-dst-srs (struct RCDataIntN [])))
            #true)

(test-equal (term (is-DST ,test-dst-srs (struct RCIntN [])))
            #false)

(test-equal (term (is-DST ,test-dst-srs (struct Cycle1 [])))
            #true)

(test-equal (term (is-DST ,test-dst-srs (struct Cycle2 [])))
            #false)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sizeof

(define-metafunction Patina-machine
  sizeof : srs ty -> z
  
  [(sizeof srs int) 
   1]
  
  [(sizeof srs (~ ty))
   1
   (side-condition (not (term (is-DST srs ty))))]
  
  [(sizeof srs (~ ty))
   2
   (side-condition (term (is-DST srs ty)))]
  
  [(sizeof srs (& ℓ mq ty))
   1
   (side-condition (not (term (is-DST srs ty))))]
  
  [(sizeof srs (& ℓ mq ty))
   2
   (side-condition (term (is-DST srs ty)))]
  
  [(sizeof srs (struct s ℓs))
   (sum [(sizeof srs ty) ...])
   (where [ty ...] (field-tys srs s ℓs))]

  [(sizeof srs (vec ty l))
   ,(* (term (sizeof srs ty)) (term l))]

  [(sizeof srs (Option ty))
   ,(add1 (term (sizeof srs ty)))]

  )

(test-equal (term (sizeof ,test-srs (struct A ())))
            (term 1))

(test-equal (term (sizeof ,test-srs (struct B (static))))
            (term 2))

(test-equal (term (sizeof ,test-srs (struct C (static))))
            (term 3))

(test-equal (term (sizeof ,test-srs (Option (struct C (static)))))
            (term 4))

(test-equal (term (sizeof ,test-srs (vec int 3)))
            (term 3))

(test-equal (term (sizeof ,test-srs (& b1 imm (vec int 3))))
            (term 1))

(test-equal (term (sizeof ,test-srs (& b1 imm (vec int erased))))
            (term 2))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sizeof-dst

(define-metafunction Patina-machine
  sizeof-dst : srs ty hv -> z
  
  [(sizeof-dst srs (vec ty) (int l))
   ,(* (term (sizeof srs ty)) (term l))]

  [(sizeof-dst srs (struct s ℓs) hv)
   (sum [z_a z_z])
   (where [ty_a ... ty_z] (field-tys srs s ℓs))
   (where z_a (sum [(sizeof srs ty_a) ...]))
   (where z_z (sizeof-dst srs ty_z hv))]

  )

(test-equal (term (sizeof ,test-srs (struct A ())))
            (term 1))

(test-equal (term (sizeof ,test-srs (struct B (static))))
            (term 2))

(test-equal (term (sizeof ,test-srs (struct C (static))))
            (term 3))

(test-equal (term (sizeof ,test-srs (Option (struct C (static)))))
            (term 4))

(test-equal (term (sizeof ,test-srs (vec int 3)))
            (term 3))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; deinit -- deinitializes a block of memory

(define-metafunction Patina-machine
  deinit : H α z -> H
  
  [(deinit H α 0) H]

  [(deinit H α z)
   (deinit (update H α void)
            ,(add1 (term α))
            ,(sub1 (term z)))])

(define-metafunction Patina-machine
  lvdeinit : srs H V T lv -> H

  [(lvdeinit srs H V T lv)
   (deinit H α z)
   (where ty (lvtype srs T lv))
   (where α (lvaddr srs H V T lv))
   (where z (sizeof srs ty))])

(test-equal (term (deinit [(10 (ptr 1))
                           (11 (int 2))
                           (12 (ptr 3))
                           (13 (ptr 4))
                           (14 (ptr 5))]
                           11
                           3))
            (term [(10 (ptr 1))
                   (11 void)
                   (12 void)
                   (13 void)
                   (14 (ptr 5))]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; memcopy -- copies memory from one address to another

(define-metafunction Patina-machine
  memcopy : H α β z -> H
  
  [(memcopy H α β 0) H]

  [(memcopy H α β z)
   (memcopy (update H α (deref H β))
            ,(add1 (term α))
            ,(add1 (term β))
            ,(sub1 (term z)))])

(test-equal (term (memcopy [(10 (ptr 1))
                            (11 (int 2))
                            (12 (ptr 3))
                            (20 (ptr 4))
                            (21 (int 5))
                            (22 (ptr 6))]
                           20
                           10
                           3))
            (term [(10 (ptr 1))
                   (11 (int 2))
                   (12 (ptr 3))
                   (20 (ptr 1))
                   (21 (int 2))
                   (22 (ptr 3))]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; memmove -- copies memory then deinitializes the source

(define-metafunction Patina-machine
  memmove : H α β z -> H
  
  [(memmove H α β z)
   (deinit (memcopy H α β z) β z)])

(test-equal (term (memmove [(10 (ptr 1))
                            (11 (int 2))
                            (12 (ptr 3))
                            (20 (ptr 4))
                            (21 (int 5))
                            (22 (ptr 6))]
                           20
                           10
                           3))
            (term [(10 void)
                   (11 void)
                   (12 void)
                   (20 (ptr 1))
                   (21 (int 2))
                   (22 (ptr 3))]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; vaddr -- lookup addr of variable in V
 
(define-metafunction Patina-machine
  vaddr : V x -> α
  
  [(vaddr V x_0)
   ,(get* (term x_0) (term V))])
         
(test-equal (term (vaddr (((a 0) (b 1)) ((c 2))) a))
            (term 0))
(test-equal (term (vaddr (((a 0) (b 1)) ((c 2))) b))
            (term 1))
(test-equal (term (vaddr (((a 0) (b 1)) ((c 2))) c))
            (term 2))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; vtype -- lookup type of variable in V
 
(define-metafunction Patina-machine
  vtype : T x -> ty
  
  [(vtype T x_0)
   ,(get* (term x_0) (term T))])

(test-equal (term (vtype ,test-T i)) (term int))

(test-equal (term (vtype ,test-T c)) (term (struct C (static))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; field-names -- determines the offsets of each field of a struct

(define-metafunction Patina-machine
  field-names : srs s ℓs -> fs
  
  [(field-names srs s ℓs)
   ,(range (term z))
   (where tys (field-tys srs s ℓs))
   (where z (len tys))]

  )

(test-equal (term (field-tys ,test-srs C ()))
            (term [0 1]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; field-offsets -- determines the offsets of each field of a struct

(define-metafunction Patina-machine
  field-offsets : srs s ℓs -> zs
  
  [(field-offsets srs s ℓs)
   (0 z ...) ;; FIXME need a prefix sum!
   (where (ty_a ... ty_z) (field-tys srs s ℓs))
   (where (z ...) [(sizeof srs ty_a) ...])]

  )

(test-equal (term (field-offsets ,test-srs C (static)))
            (term (0 1)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; vec-offsets -- determines the offsets of each element of a vector

(define-metafunction Patina-machine
  vec-offsets : srs ty l -> zs

  [(vec-offsets srs ty 0)
   []]
  
  [(vec-offsets srs ty 1)
   [0]]
  
  [(vec-offsets srs ty l) ;; really, really inefficient. 
   (z_a ... z_y (offset z_y (sizeof srs ty)))
   (where [z_a ... z_y] (vec-offsets srs ty (dec l)))]

  )

(test-equal (term (vec-offsets ,test-srs int 3))
            (term (0 1 2)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; vec-tys -- returns the types of each element in a vector,
;; which is just the vector element type repeated N times

(define-metafunction Patina-machine
  vec-tys : srs ty l -> tys

  [(vec-tys srs ty 0)
   []]
  
  [(vec-tys srs ty 1)
   [ty]]
  
  [(vec-tys srs ty l)
   (ty ty_a ...)
   (where [ty_a ...] (vec-tys srs ty (dec l)))]

  )

(test-equal (term (vec-tys ,test-srs int 3))
            (term (int int int)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; offsetof

(define-metafunction Patina-machine
  offsetof : srs s ℓs f -> z
  
  [(offsetof srs s ℓs f)
   ,(foldl + 0 (map (λ (t) (term (sizeof srs ,t)))
                    (take (term (field-tys srs s ℓs))
                          (term f))))])

(test-equal (term (offsetof ,test-srs C (static) 0))
            (term 0))

(test-equal (term (offsetof ,test-srs C (static) 1))
            (term 1))

(test-equal (term (offsetof ,test-srs D (static) 1))
            (term 3))

(test-equal (term (offsetof ,test-srs D (static) 3))
            (term 7))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; lvtype -- compute type of an lvalue

(define-metafunction Patina-machine
  dereftype : ty -> ty
  
  [(dereftype (~ ty)) ty]
  [(dereftype (& ℓ mq ty)) ty])

(define-metafunction Patina-machine
  fieldtype : srs ty f -> ty
  
  [(fieldtype srs (struct s ℓs) f)
   ,(car (drop (term (field-tys srs s ℓs)) (term f)))]) ; fixme--surely a better way

(define-metafunction Patina-machine
  lvtype : srs T lv -> ty
  
  [(lvtype srs T x)
   (vtype T x)]
  
  [(lvtype srs T (* lv))
   (dereftype (lvtype srs T lv))]
  
  [(lvtype srs T (lv · f))
   (fieldtype srs (lvtype srs T lv) f)])

(test-equal (term (lvtype ,test-srs ,test-T (* p))) (term int))

;; FIXME --> l0 should be static
(test-equal (term (lvtype ,test-srs ,test-T (c · 1))) (term (struct B (l0))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; lvaddr -- lookup addr of variable in V

(define-metafunction Patina-machine
  lvaddr-elem : srs H V T ty l lv lv -> z

  [(lvaddr-elem srs H V T ty_e l_v lv_v lv_i)
   (offset (lvaddr srs H V T lv_v) z_e)
   (where α_i (lvaddr srs H V T lv_i))
   (where (int l_i) (deref H α_i))
   (where z_e ,(* (term l_i) (term (sizeof srs ty_e))))
   (side-condition (>= (term l_i) 0))
   (side-condition (< (term l_i) (term l_v)))]

  )

(define-metafunction Patina-machine
  lvaddr : srs H V T lv -> α
  
  [(lvaddr srs H V T x)
   (vaddr V x)]
  
  [(lvaddr srs H V T (* lv))
   α
   (where (ptr α) (deref H (lvaddr srs H V T lv)))]
       
  [(lvaddr srs H V T (lv · f))
   (offset (lvaddr srs H V T lv)
           (offsetof srs s ℓs f))
   (where (struct s ℓs) (lvtype srs T lv))]

  ;; indexing into a fixed-length vector
  [(lvaddr srs H V T (lv_v @ lv_i))
   (lvaddr-elem srs H V T ty_e l_v lv_v lv_i)
   (where (vec ty_e l_v) (lvtype srs T lv_v))]

  ;; indexing into a dynamically sized vector
  [(lvaddr srs H V T (lv_v @ lv_i))
   (lvaddr-elem srs H V T ty_e l_v lv_v lv_i)
   (where (vec ty_e erased) (lvtype srs T lv_v))
   (where (int l_v) (reified srs H V T lv_v))]

  )

(test-equal (term (lvaddr ,test-srs ,test-H ,test-V ,test-T (c · 1)))
            (term 16))

(test-equal (term (lvaddr ,test-srs ,test-H ,test-V ,test-T ((c · 1) · 1)))
            (term 17))

(test-equal (term (lvaddr ,test-srs ,test-H ,test-V ,test-T (* ((c · 1) · 1))))
            (term 97))

(test-equal (term (lvaddr ,test-srs ,test-H ,test-V ,test-T (ints3 @ i1)))
            (term 23))

;(test-equal (term (lvaddr ,test-srs ,test-H ,test-V ,test-T (ints3 @ i4)))
;            (term 23))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; reified -- given a LV of DST type, identifies and returns the "reified"
;; portion (i.e., the length). Must be behind the most recent pointer.

(define-metafunction Patina-machine
  reified : srs H V T lv -> hv

  [(reified srs H V T (* lv))
   (deref H (inc α))
   (where α (lvaddr srs H V T lv))]

  [(reified srs H V T (lv_o · f))
   (reified srs H V T lv_o)]

  [(reified srs H V T (lv_v @ lv_i))
   (reified srs H V T lv_v)]

  )

(test-equal (term (reified ,test-srs ,test-H ,test-V ,test-T
                           ((* intsp) @ i2)))
            (term (int 3)))

(test-equal (term (lvaddr ,test-srs ,test-H ,test-V ,test-T ((* intsp) @ i1)))
            (term 23))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; malloc -- extend heap z contiguous addresses and retun starting address

(define-metafunction Patina-machine
  malloc : H z -> (H α)

  [(malloc H z)
   (H_1 β)
   (where ((α hv) ...) H)
   (where β ,(add1 (apply max (term (-1 α ...)))))
   (where H_1 (extend H β z))])

(test-equal (cadr (term (malloc ,test-H 2))) 100)
(test-equal (cadr (term (malloc () 2))) 0)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; movemany -- like memmove but for a series of regions

(define-metafunction Patina-machine
  movemany : H zs αs βs -> H

  [(movemany H () () ())
   H]

  [(movemany H (z_0 z_1 ...) (α_0 α_1 ...) (β_0 β_1 ...))
   (movemany (memmove H α_0 β_0 z_0)
             (z_1 ...)
             (α_1 ...)
             (β_1 ...))])

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; reify-pack -- extract out the static part of some type that is to be
;; packed and reify into a heap value

(define-metafunction Patina-machine
  reify-pack : srs ty ty -> hv

  [(reify-pack srs (vec ty l) (vec ty erased))
   (int l)]

  [(reify-pack srs (struct s_s ℓs_s) (struct s_d ℓs_d))
   (reify-pack srs ty_s^z ty_d^z)
   (where (ty_s^a ... ty_s^z) (field-tys srs s_s ℓs_s))
   (where (ty_d^a ... ty_d^z) (field-tys srs s_d ℓs_d))]

  )

(test-equal (term (reify-pack ,test-dst-srs (vec int 22) (vec int erased)))
            (term (int 22)))

(test-equal (term (reify-pack ,test-dst-srs (struct RCDataInt3 []) (struct RCDataIntN [])))
            (term (int 3)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; rveval -- evaluate an rvalue and store it into the heap at address α

(define-metafunction Patina-machine
  rveval : srs H V T α rv -> H

  [(rveval srs H V T α (copy lv))
   H_1
   (where ty (lvtype srs T lv))
   (where z (sizeof srs ty))
   (where β (lvaddr srs H V T lv))
   (where H_1 (memcopy H α β z))]

  [(rveval srs H V T α (lv))
   H_1
   (where ty (lvtype srs T lv))
   (where z (sizeof srs ty))
   (where β (lvaddr srs H V T lv))
   (where H_1 (memmove H α β z))]

  [(rveval srs H V T α (& ℓ mq lv))
   H_1
   (where β (lvaddr srs H V T lv))
   (where ty (lvtype srs T lv))
   (where H_1 (update H α (ptr β)))
   (side-condition (not (term (is-DST srs ty))))]

  [(rveval srs H V T α (& ℓ mq lv))
   H_2
   (where β (lvaddr srs H V T lv))
   (where ty (lvtype srs T lv))
   (where (int l) (reified srs H V T lv))
   (where H_1 (update H α (ptr β)))
   (where H_2 (update H_1 (inc α) (int l)))
   (side-condition (term (is-DST srs ty)))]

  [(rveval srs H V T α (struct s ℓs lvs))
   (movemany H zs_0 βs αs)

   ;; types of each field:
   (where tys (field-tys srs s ℓs))
   ;; sizes of each field's type:
   (where zs_0 ,(map (λ (t) (term (sizeof srs ,t))) (term tys)))
   ;; offset of each field:
   (where zs_1 (field-offsets srs s lvs))
   ;; source address of value for each field:
   (where αs ,(map (λ (lv) (term (lvaddr srs H V T ,lv))) (term lvs)))
   ;; target address for each field relative to base address α;
   (where βs ,(map (λ (z) (+ (term α) z)) (term zs_1)))]

  [(rveval srs H V T α (new lv))
   (update H_2 α (ptr γ))

   (where ty (lvtype srs T lv))
   (where z (sizeof srs ty))
   (where β (lvaddr srs H V T lv))
   (where (H_1 γ) (malloc H z))
   (where H_2 (memmove H_1 γ β z))]
   
  [(rveval srs H V T α number)
   (update H α (int number))]
   
  [(rveval srs H V T α (lv_l + lv_r))
   (update H α (int number_s))

   (where α_l (lvaddr srs H V T lv_l))
   (where α_r (lvaddr srs H V T lv_r))
   (where (int number_l) (deref H α_l))
   (where (int number_r) (deref H α_r))
   (where number_s (offset number_l number_r))]

  [(rveval srs H V T α (Some lv))
   H_2

   (where ty (lvtype srs T lv))
   (where z (sizeof srs ty))
   (where β (lvaddr srs H V T lv))
   (where α_p ,(add1 (term α)))
   (where H_1 (memmove H α_p β z))
   (where H_2 (update H_1 α (int 1)))]

  [(rveval srs H V T α (None ty))
   (update H α (int 0))]

  [(rveval srs H V T α (vec ty))
   H]

  [(rveval srs H V T α (vec ty lv_e ...))
   H_1

   ;; find addresses α_e of the inputs lv_e
   (where [α_e ...] [(lvaddr srs H V T lv_e) ...])
   ;; determine ty of vector from type of 1st lvalue
   (where [lv_a lv_b ...] [lv_e ...])
   (where ty (lvtype srs T lv_a))
   ;; length of vector comes from number of lvalues
   (where l_v (len [lv_a lv_b ...]))
   ;; find types/sizes of the elements (always the same for each element)
   (where [ty_e ...] (vec-tys srs ty l_v))
   (where [z_e ...] [(sizeof srs ty_e) ...])
   ;; find addresses β_e of each element
   (where [z_o ...] (vec-offsets srs ty l_v))
   (where [β_e ...] ((offset α z_o) ...))
   ;; move lvalues into their new homes
   (where H_1 (movemany H [z_e ...] [β_e ...] [α_e ...]))]

  ;; pack from ~ty_s to ~ty_d where ty_d is DST
  ;; (see nearly identical borrowed pointer rule below)
  [(rveval srs H V T α (pack lv_s (~ ty_d)))
   H_2

   ;; move pointer value
   (where α_s (lvaddr srs H V T lv_s))
   (where H_1 (memmove H α α_s 1))

   ;; reify component of type and store into heap at offset 1 of fat
   ;; pointer
   (where (~ ty_s)  (lvtype srs T lv))
   (where hv (reify-pack srs ty_s ty_d))
   (where H_2 (update H_1 (inc α) hv))]

  ;; pack from &ty_s to &ty_d where ty_d is DST
  ;; (see nearly identical owned pointer rule above)
  [(rveval srs H V T α (pack lv_s (& ℓ mq ty_d)))
   H_2

   ;; move pointer value
   (where α_s (lvaddr srs H V T lv_s))
   (where H_1 (memmove H α α_s 1))

   ;; reify component of type and store into heap at offset 1 of fat
   ;; pointer
   (where (& ℓ mq ty_s)  (lvtype srs T lv_s))
   (where hv (reify-pack srs ty_s ty_d))
   (where H_2 (update H_1 (inc α) hv))]

  ;; len for non-DST
  [(rveval srs H V T α (vec-len lv))
   (update H α (int l))
   (where (vec ty l) (lvtype srs T lv))]

  ;; len for DST
  [(rveval srs H V T α (vec-len lv))
   (update H α (reified srs H V T lv))
   (where (vec ty erased) (lvtype srs T lv))]

  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; lvselect -- helper for writing tests, selects values for a portion
;; of the heap

(define-metafunction Patina-machine
  lvselect : srs H V T lv -> (hv ...)
  
  [(lvselect srs H V T lv)
   ,(select (term H) (term α) (term z))

   (where ty (lvtype srs T lv))
   (where α (lvaddr srs H V T lv))
   (where z (sizeof srs ty))])

;; tests for rveval and lvselect

(test-equal (term (lvselect ,test-srs
                            (rveval ,test-srs ,test-H ,test-V ,test-T
                                    (vaddr ,test-V c)
                                    (struct C (b1) (a b)))
                            ,test-V
                            ,test-T
                            c))
            (term ((int 23) (int 24) (ptr 98))))

(test-equal (term (lvselect ,test-srs
                            (rveval ,test-srs ,test-H ,test-V ,test-T
                                    (vaddr ,test-V c)
                                    (struct C (b1) (a b)))
                            ,test-V
                            ,test-T
                            a))
            (term (void)))

(test-equal (term (lvselect ,test-srs
                            (rveval ,test-srs ,test-H ,test-V ,test-T
                                    (vaddr ,test-V p)
                                    (new i))
                            ,test-V
                            ,test-T
                            p))
            (term ((ptr 100))))

(test-equal (term (lvselect ,test-srs
                            (rveval ,test-srs ,test-H ,test-V ,test-T
                                    (vaddr ,test-V p)
                                    (new i))
                            ,test-V
                            ,test-T
                            p))
            (term ((ptr 100))))

(test-equal (term (deref (rveval ,test-srs ,test-H ,test-V ,test-T
                                 (vaddr ,test-V p)
                                 (new i)) 100))
            (term (int 22))) ;; *p now contains value of i

(test-equal (term (lvselect ,test-srs
                            (rveval ,test-srs ,test-H ,test-V ,test-T
                                    (vaddr ,test-V q)
                                    (& mq imm (* ((c · 1) · 1))))
                            ,test-V
                            ,test-T
                            q))
            (term ((ptr 97))))

(test-equal (term (lvselect ,test-srs
                            (rveval ,test-srs ,test-H ,test-V ,test-T
                                    (vaddr ,test-V i)
                                    (i + (* p)))
                            ,test-V
                            ,test-T
                            i))
            (term ((int 49))))

;; test that `None` writes a 0 into the discriminant, leaves rest unchanged
(test-equal (term (lvselect ,test-srs
                            (rveval ,test-srs ,test-H ,test-V ,test-T
                                    (vaddr ,test-V s)
                                    (None int))
                            ,test-V
                            ,test-T
                            s))
            (term ((int 0) (ptr 95))))

;; test that `(Some p)` writes a 1 into the discriminant
(test-equal (term (lvselect ,test-srs
                            (rveval ,test-srs ,test-H ,test-V ,test-T
                                    (vaddr ,test-V s)
                                    (Some p))
                            ,test-V
                            ,test-T
                            s))
            (term ((int 1) (ptr 99))))

;; test that `(Some p)` deinitializes `p`
(test-equal (term (lvselect ,test-srs
                            (rveval ,test-srs ,test-H ,test-V ,test-T
                                    (vaddr ,test-V s)
                                    (Some p))
                            ,test-V
                            ,test-T
                            p))
            (term (void)))

;; test `(vec int i1 i2 i3)`
(test-equal (term (lvselect ,test-srs
                            (rveval ,test-srs ,test-H ,test-V ,test-T
                                    (vaddr ,test-V ints3)
                                    (vec int i1 i2 i3))
                            ,test-V
                            ,test-T
                            ints3))
            (term ((int 1) (int 2) (int 3))))

;; test pack
(test-equal (term (lvselect ,test-srs
                            (rveval ,test-srs
                                    ;; clear out the initial value of intsp,
                                    ;; then put it back
                                    (lvdeinit ,test-srs ,test-H ,test-V ,test-T
                                              intsp)
                                    ,test-V
                                    ,test-T
                                    (vaddr ,test-V intsp)
                                    (pack ints3p (& b1 imm (vec int erased))))
                            ,test-V
                            ,test-T
                            intsp))
            (term ((ptr 22) (int 3))))

;; test len for non-DST
(test-equal (term (lvselect ,test-srs
                            (rveval ,test-srs
                                    ,test-H
                                    ,test-V
                                    ,test-T
                                    (vaddr ,test-V i)
                                    (vec-len ints3))
                            ,test-V
                            ,test-T
                            i))
            (term ((int 3))))

;; test len for DST
(test-equal (term (lvselect ,test-srs
                            (rveval ,test-srs
                                    ,test-H
                                    ,test-V
                                    ,test-T
                                    (vaddr ,test-V i)
                                    (vec-len (* intsp)))
                            ,test-V
                            ,test-T
                            i))
            (term ((int 3))))

;; test taking address of DST
(test-equal (term (lvselect ,test-srs
                            (rveval ,test-srs
                                    ,test-H
                                    ,test-V
                                    ,test-T
                                    (vaddr ,test-V intsp)
                                    (& b1 imm (* intsp)))
                            ,test-V
                            ,test-T
                            intsp))
            (term ((ptr 22) (int 3))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; free -- frees the memory owned by `α` which has type `ty`
;;
;; Note that this does *not* free (or deinitialize) `α` itself!

(define-metafunction Patina-machine
  free-at-offsets : srs H α (ty ...) (z ...) -> H

  [(free-at-offsets srs H α () ())
   H]

  [(free-at-offsets srs H α (ty_0 ty_1 ...) (z_0 z_1 ...))
   (free-at-offsets srs H_1 α (ty_1 ...) (z_1 ...))
   (where H_1 (free srs H ty_0 (offset α z_0)))]
  
  )

(define-metafunction Patina-machine
  free-vec : srs H α ty l -> H

  [(free-vec srs H α ty l)
   (free-at-offsets srs H α
                    (vec-tys srs ty l)
                    (vec-offsets srs ty l))]

  )

(define-metafunction Patina-machine
  free-dst : srs H ty α hv -> H

  [(free-dst srs H (vec ty erased) α (int z))
   (free-vec srs H α ty z)]

  [(free-dst srs H (struct s ℓs) α)
   (free-dst srs H_1 ty_z (offset α z_z) hv)
   (where (ty_a ... ty_z) (field-tys srs s ℓs))
   (where (z_a ... z_z) (field-offsets srs s ℓs))
   (where H_1 (free-at-offsets srs H α (ty_a ...) (z_a ...)))]

  )

(define-metafunction Patina-machine
  free : srs H ty α -> H

  [(free srs H ty α)
   H
   (side-condition (term (is-void (deref H α))))]
  
  [(free srs H int α)
   H]

  [(free srs H (vec ty z) α)
   (free-vec srs H α ty z)]

  [(free srs H (& ℓ mq ty) α) H]

  [(free srs H (~ ty) α)
   H_2
   (where (ptr β) (deref H α))
   (where z (sizeof srs ty))
   (where H_1 (free srs H ty β))
   (where H_2 (shrink H_1 β z))
   (side-condition (not (term (is-DST srs ty))))]

  [(free srs H (~ ty) α_0)
   H_2
   (where (ptr β) (deref H α))
   (where hv (deref H (inc α)))
   (where z (sizeof-dst srs ty hv))
   (where H_1 (free-dst srs H ty β hv))
   (where H_2 (shrink H_1 β z))
   (side-condition (term (is-DST srs ty)))]

  [(free srs H (struct s ℓs) α)
   (free-at-offsets srs H α tys zs)
   (where tys (field-tys srs s ℓs))
   (where zs (field-offsets srs s ℓs))]

  [(free srs H (Option ty) α)
   H
   (where (int 0) (deref H α))]

  [(free srs H (Option ty) α)
   (free srs H ty ,(add1 (term α)))
   (where (int 1) (deref H α))]
)

(define-metafunction Patina-machine
  lvfree : srs H V T lv -> H

  [(lvfree srs H V T lv)
   (free srs H ty α)
   (where ty (lvtype srs T lv))
   (where α (lvaddr srs H V T lv))])

(test-equal (term (lvfree ,test-srs ,test-H ,test-V ,test-T p))
            (term (shrink ,test-H 99 1)))

(test-equal (term (lvdeinit ,test-srs
                            (lvfree ,test-srs ,test-H ,test-V ,test-T p)
                            ,test-V
                            ,test-T
                            p))
            (term (deinit (shrink ,test-H 99 1) 11 1)))
            
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; free-variables -- free variables upon exit from a block,
;; also removes memory used by those variables

(define-metafunction Patina-machine
  free-variables : srs H vmap vdecls -> H

  [(free-variables srs H () ()) H]
  [(free-variables srs
                   H
                   ((x_0 α_0) (x_1 α_1) ...)
                   ((x_0 ty_0) (x_1 ty_1) ...))
   (shrink (free srs H_1 ty_0 α_0) α_0 z)
   (where z (sizeof srs ty_0))
   (where H_1 (free-variables srs
                              H
                              ((x_1 α_1) ...)
                              ((x_1 ty_1) ...)))])

;; this should free up all memory but that which pertains to `i` and `p`,
;; as well as `97` and `98` which are marked as 'static'
(test-equal (term (free-variables ,test-srs
                                  ,test-H
                                  ,(cadr test-V)
                                  ,(cadr test-T)))
            (term ((10 (int 22))
                   (11 (ptr 99))
                   (97 (int 29))
                   (98 (int 28))
                   (99 (int 27)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; alloc-variables -- allocate space for variables upon entry to a block,
;; filling the memory with void

(define-metafunction Patina-machine
  alloc-variables : srs H ((x ty) ...) -> (vmap vdecls H)

  [(alloc-variables srs H ()) (() () H)]
  [(alloc-variables srs H ((x_0 ty_0) (x_1 ty_1) ...))
   (((x_0 α_0) (x_2 α_2) ...)
    ((x_0 ty_0) (x_2 ty_2) ...)
    H_2)
   (where z (sizeof srs ty_0))
   (where (H_1 α_0) (malloc H z))
   (where (((x_2 α_2) ...)
           ((x_2 ty_2) ...)
           H_2) (alloc-variables srs H_1 ((x_1 ty_1) ...)))])

;; this should free up all memory but that which pertains to `i` and `p`,
;; as well as `97` and `98` which are marked as 'static'
(test-equal (term (alloc-variables ,test-srs
                                   ,test-H
                                   ((j int)
                                    (k (struct B (static))))))
            (term (((j 100) (k 101))
                   ((j int) (k (struct B (static))))
                   ,(append (term ((102 void) (101 void) (100 void)))
                            test-H))))

;; unwrap

(define-metafunction Patina-machine
  unwrap : srs H ℓ mode ty α -> (H ty α)
  
  [(unwrap srs H ℓ (ref mq) ty α)
   (H_u ty_m α_m)
   ;; type of variable `x_m`
   (where ty_m (& ℓ mq ty))
   ;; generate memory for `x_m`
   (where (H_m α_m) (malloc H (sizeof srs ty_m)))
   ;; update mem location with ptr to payload
   (where H_u (update H_m α_m (ptr α)))]

  [(unwrap srs H ℓ move ty α)
   (H_u ty α_m)
   ;; generate memory for `x_m`
   (where (H_m α_m) (malloc H (sizeof srs ty)))
   ;; move payload from α into α_m
   (where H_u (memmove H_m α_m α (sizeof srs ty)))]
  )

(test-equal (term (unwrap ,test-srs ,test-H l1 (ref mut) (~ int)
                          ,(add1 (term (vaddr ,test-V s)))))
            (term (,(append (term [(100 (ptr 21))]) test-H)
                   (& l1 mut (~ int))
                   100)))

(test-equal (term (unwrap ,test-srs ,test-H l1 move (~ int)
                          ,(add1 (term (vaddr ,test-V s)))))
            (term (,(append (term [(100 (ptr 95))])
                            (term (deinit ,test-H 21 1)))
                   (~ int)
                   100)))

;; --> -- machine step from one configuration C to the next

(define machine-step
  (reduction-relation
   Patina-machine
   
   ;; Stack frame with no more statements. Free variables.
   [--> ((srs fns) H [vmap_0 vmap_1 ...] [vdecls_0 vdecls_1 ...]
         [(ℓ ()) sf_1 ...])
        ((srs fns) H_1 [vmap_1 ...] [vdecls_1 ...] [sf_1 ...])
        (where H_1 (free-variables srs H vmap_0 vdecls_0))]

   ;; Assignments. The memory for the lvalue should always be alloc'd,
   ;; but not initialized.
   [--> ((srs fns) H V T [(ℓ ((lv = rv) st ...)) sf ...])
        ((srs fns) H_1 V T [(ℓ (st ...)) sf ...])
        (where α (lvaddr srs H V T lv))
        (where H_1 (rveval srs H V T α rv))]

   ;; Frees. The memory for the lvalue should be fully initialized.
   [--> ((srs fns) H V T [(ℓ ((free lv) st ...)) sf ...])
        ((srs fns) H_2 V T [(ℓ (st ...)) sf ...])
        (where H_1 (lvfree srs H V T lv))
        (where H_2 (lvdeinit srs H_1 V T lv))]

   ;; Match, None case.
   [--> ((srs fns) H V T [(ℓ [st_a st ...]) sf ...])
        ((srs fns) H [() vmap ...] [() vdecls ...] [(ℓ_m [bk_n]) (ℓ [st ...]) sf ...])
        ;; st_a is some kind of match:
        (where (match lv_d (Some mode x_d => bk_s) (None => bk_n)) st_a)
        ;; the discriminant lies at address α_d:
        (where α_d (lvaddr srs H V T lv_d))
        ;; it is a None value:
        (where (int 0) (deref H α_d))
        ;; generate a fresh lifetime: (FIXME)
        (where ℓ_m lmatch)
        ;; unpack V and T
        (where ([vmap ...] [vdecls ...]) (V T))
        ]

   ;; Match, some case.
   [--> ((srs fns) H V T [(ℓ [st_a st ...]) sf ...])
        C_n
        ;; st_a is a match:
        (where (match lv_d (Some mode x_m => bk_s) (None => bk_n)) st_a)
        ;; the discriminant lies at address α_d:
        (where α_d (lvaddr srs H V T lv_d))
        ;; the discriminant has Option type:
        (where (Option ty) (lvtype srs T lv_d))
        ;; it is a Some value:
        (where (int 1) (deref H α_d))
        ;; make a pointer to the payload:
        (where α_v ,(add1 (term α_d)))
        ;; generate a fresh lifetime: (FIXME)
        (where ℓ_m lmatch)
        ;; handle the ref/move into `x_m`:
        (where (H_m ty_m α_m) (unwrap srs H ℓ_m mode ty α_v))
        ;; create new entry for vmap/vdecls
        (where vmap_m [(x_m α_m)])
        (where vdecls_m [(x_m ty_m)])
        ;; unpack V and T
        (where ([vmap ...] [vdecls ...]) (V T))
        (where C_n ((srs fns) H_m [vmap_m vmap ...] [vdecls_m vdecls ...]
         [(ℓ_m [bk_s]) (ℓ [st ...]) sf ...]))
        ]

   ;; Push a new block.
   [--> ((srs fns) H (vmap ...) (vdecls ...)
         [sf_1 sf_2 ...])
        ((srs fns) H_1  [vmap_b vmap ...] [vdecls_b vdecls ...]
         [sf_b (ℓ_1 [st_1 ...]) sf_2 ...])

        ;; unpack the top-most stack frame sf_1:
        (where (ℓ_1 [st_0 st_1 ...]) sf_1)
        ;; unpack the next statement st_0, which should be a block:
        (where (block ℓ_b vdecls_b [st_b ...]) st_0)
        ;; allocate space for block svariables in memory:
        (where (vmap_b vdecls_b H_1) (alloc-variables srs H vdecls_b))
        ;; create new stack frame for block
        ;; FIXME substitute a fresh lifetime for ℓ_b
        (where sf_b (ℓ_b (st_b ...)))
        ]

   ;; Push a call.
   [--> ((srs fns) H V T S)
        ((srs fns) H_2 [vmap_a vmap ...] [vdecls_a vdecls ...]
         [(lX (bk_f)) (ℓ_1 [st_r ...]) sf_r ...])

        ;; unpack V and T for later expansion
        (where ([vmap ...] [vdecls ...]) (V T))
        ;; unpack the stack frames:
        (where [(ℓ_1 sts_1) sf_r ...] S)
        ;; unpack the statements sts_1 from top-most activation:
        (where ((call g ℓs_a lvs_a) st_r ...) sts_1)
        ;; determine the types of the actual args to be passed:
        (where tys_a ,(map (λ (lv) (term (lvtype srs T ,lv)))
                           (term lvs_a)))
        ;; determine sizes of those types
        (where zs_a ,(map (λ (ty) (term (sizeof srs ,ty)))
                          (term tys_a)))
        ;; determine where lvalues are found in memory
        (where αs_a ,(map (λ (lv) (term (lvaddr srs H V T ,lv)))
                              (term lvs_a)))
        ;; lookup the fun def'n (FIXME s/ℓs_f/ℓs_a/):
        (where (fun g ℓs_f vdecls_f bk_f) (fun-defn fns g))
        ;; allocate space for parameters in memory:
        (where (vmap_a vdecls_a H_1) (alloc-variables srs H vdecls_f))
        ;; determine addresses for each formal argument:
        (where ((x_f ty_f) ...) vdecls_f)
        (where βs_f ,(map (λ (lv) (term (lvaddr srs H_1
                                                        (vmap_a) (vdecls_a)
                                                        ,lv)))
                             (term (x_f ...))))
        ;; move from actual params into formal params:
        (where H_2 (movemany H_1 zs_a βs_f αs_a))
        ]
   ))

;; test stepping where top-most stack frame has no remaining statements
(test--> machine-step
         (term (,twentytwo-prog () (()) (()) ((l0 ()))))
         (term (,twentytwo-prog () () () ())))

;; test popping off a stack frame with vars and another frame beneath
(test--> machine-step
         (term (,twentytwo-prog
                [(0 (int 22)) (1 (int 23))]
                [[(j 1)] [(i 0)]]
                [[(j int)] [(i int)]]
                [(l0 []) (l1 [])]))
         (term (,twentytwo-prog
                [(0 (int 22))]
                [[(i 0)]]
                [[(i int)]]
                [(l1 [])])))

;;;; test pushing a new block
(test--> machine-step
         (term (,twentytwo-prog
                [(0 (int 22))]
                [[(a 0)]]
                [[(a int)]]
                [(l1 [(block l2
                             [(b int)
                              (c (~ int))]
                             [(i = 2)
                              (j = (new i))])])]))
          (term (,twentytwo-prog
                 [(2 void) (1 void) (0 (int 22))]
                 [[(b 1) (c 2)] [(a 0)]]
                 [[(b int) (c (~ int))] [(a int)]]
                 [(l2 [(i = 2) (j = (new i))])
                  (l1 [])])))

;; test a series of state steps, starting from the initial state.
;; This tests:
;; - function calls
;; - block activation
;; - assignment (through a pointer)
;; - popping

(define state-0
  (term (,twentytwo-prog ,initial-H ,initial-V ,initial-T ,initial-S)))
(check-not-false (redex-match Patina-machine C state-0))

(define state-1
  (term (,twentytwo-prog
         [(2 (ptr 0)) (0 (int 0)) (1 void)]
         [[(outp 2)] [(resultp 1)]]
         [[(outp (& a mut int))] [(resultp (& l0 mut int))]]
         [(lX [(block l0 [] (((* outp) = 22)))])
          (l0 [])])))
(check-not-false (redex-match Patina-machine C state-1))

(define state-2
  (term (,twentytwo-prog
         [(2 (ptr 0)) (0 (int 0)) (1 void)]
         [[] [(outp 2)] [(resultp 1)]]
         [[] [(outp (& a mut int))] [(resultp (& l0 mut int))]]
         [(l0 [((* outp) = 22)])
          (lX [])
          (l0 [])])))
(check-not-false (redex-match Patina-machine C state-2))

(define state-3
  (term (,twentytwo-prog
         [(2 (ptr 0)) (0 (int 22)) (1 void)]
         [[] [(outp 2)] [(resultp 1)]]
         [[] [(outp (& a mut int))] [(resultp (& l0 mut int))]]
         [(l0 [])
          (lX [])
          (l0 [])])))
(check-not-false (redex-match Patina-machine C state-3))

(define state-N
  (term (,twentytwo-prog
         [(0 (int 22))]
         []
         []
         [])))
(check-not-false (redex-match Patina-machine C state-N))

(test--> machine-step state-0 state-1)
(test--> machine-step state-1 state-2)
(test--> machine-step state-2 state-3)
(test-->> machine-step state-0 state-N)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; test summation example

(define sum-state-0
  (term (,sum-prog ,initial-H ,initial-V ,initial-T ,initial-S)))
(check-not-false (redex-match Patina-machine C sum-state-0))

(define sum-state-N
  (term (,sum-prog [(0 (int 66))] [] [] [])))
(check-not-false (redex-match Patina-machine C sum-state-N))

(test-->> machine-step sum-state-0 sum-state-N)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; test dst example

(define dst-state-0
  (term (,dst-prog ,initial-H ,initial-V ,initial-T ,initial-S)))
(check-not-false (redex-match Patina-machine C dst-state-0))

(define dst-state-N
  (term (,dst-prog [(0 (int 69))] [] [] [])))
(check-not-false (redex-match Patina-machine C dst-state-N))

(test-->> machine-step dst-state-0 dst-state-N)

;;;;
;;
;; TYPING RULES
;;
;;;;

(define-extended-language Patina-typing Patina-machine
  ;; initialization: lists lvalues that have been initialized
  (ℑ (lv ...))

  ;; lifetime declaration: lifetime ℓ is in scope, and it is a sublifetime
  ;; of ℓs
  (λ (ℓ ℓs))
  (λs (λ ...))

  ;; lifetime relation: what lifetimes are in scope; in future, what
  ;; is their relation to one another
  (Λ λs)

  ;; in-scope loans
  (loan (ℓ mq lv))
  (£ [loan ...])
         
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ty-is-pod

(define-judgment-form
  Patina-typing
  #:mode (ty-is-pod I I)
  #:contract (ty-is-pod srs ty)

  [--------------------------------------------------
   (ty-is-pod srs int)]

  [--------------------------------------------------
   (ty-is-pod srs (& ℓ imm ty))]

  [--------------------------------------------------
   (ty-is-pod srs (Option ty))]

  [--------------------------------------------------
   (ty-is-pod srs (Option ty))]

  [(where [ty_s ...] (field-tys srs s ℓs))
   (ty-is-pod srs ty_s) ...
   --------------------------------------------------
   (ty-is-pod srs (struct s ℓs))]
   
  )

(test-equal
 (judgment-holds
  (ty-is-pod [] int))
 #t)

(test-equal
 (judgment-holds
  (ty-is-pod [] (~ int)))
 #f)

(test-equal
 (judgment-holds
  (ty-is-pod ,test-srs (struct A [])))
 #t)

(test-equal
 (judgment-holds
  (ty-is-pod ,test-srs (struct E [])))
 #f)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; lv-initialized ℑ lv
;; lv-not-initialized ℑ lv
;;
;; Hold if the lvalue lv is or is not initialized, respectively.

(define-judgment-form
  Patina-typing
  #:mode     (lv-initialized I I )
  #:contract (lv-initialized ℑ lv)

  [(side-condition (∈ lv ℑ))
   --------------------------------------------------
   (lv-initialized ℑ lv)]
  )

(define-judgment-form
  Patina-typing
  #:mode     (lv-not-initialized I I )
  #:contract (lv-not-initialized ℑ lv)

  [(side-condition (∉ lv ℑ))
   --------------------------------------------------
   (lv-not-initialized ℑ lv)]
  )

(test-equal
 (judgment-holds (lv-initialized [a b] a))
 #t)

(test-equal
 (judgment-holds (lv-initialized [a b] b))
 #t)

(test-equal
 (judgment-holds (lv-initialized [a b] c))
 #f)

(test-equal
 (judgment-holds (lv-not-initialized [a b] a))
 #f)

(test-equal
 (judgment-holds (lv-not-initialized [a b] b))
 #f)

(test-equal
 (judgment-holds (lv-not-initialized [a b] c))
 #t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; in-scope-lifetimes
;;
;; Convert a Λ to a list ℓs of in-scope lifetimes

(define-metafunction Patina-typing
  in-scope-lifetimes : Λ -> ℓs

  [(in-scope-lifetimes ((ℓ ℓs) ...)) (ℓ ...)])

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; loaned-paths

(define-metafunction Patina-typing
  loaned-paths : £ -> lvs

  [(loaned-paths [(ℓ mq lv) ...]) (lv ...)])

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; owning-path srs ty lv -> lv
;;
;; Returns the largest owned prefix of `lv`. For example, if `lv` is
;; `x.f`, then it would return `x.f`. If `lv` were `(*x).f`, then the
;; result would either be `(*x).f` if `x` is an owned pointer (i.e.,
;; `~T`), or `x` if `x` is a reference (e.g., `&T`).

(define-metafunction Patina-typing
  owning-path : srs ty lv -> lv

  [(owning-path srs ty lv)
   (owning-path1 srs ty lv lv)]

  )

;; Helper function. Second argument is the maximal owned path found so
;; far.
(define-metafunction Patina-typing
  owning-path1 : srs T lv lv-> lv

  [(owning-path1 srs T x lv_m) lv_m]

  [(owning-path1 srs T (lv_0 · f) lv_m)
   (owning-path1 srs T lv_0 lv_m)]

  [(owning-path1 srs T (lv_0 @ lv_1) lv_m)
   (owning-path1 srs T lv_0 lv_m)]

  [(owning-path1 srs T (* lv_0) lv_m)
   (owning-path1 srs T lv_0 lv_m)
   (where (~ ty) (lvtype srs T lv_0))]

  [(owning-path1 srs T (* lv_0) lv_m)
   (owning-path1 srs T lv_0 lv_0)
   (where (& ℓ mq ty) (lvtype srs T lv_0))]

  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; path-and-base-paths lv
;;
;; Given something like (*x).f, yields: [(*x).f, *x, x]

(define-metafunction Patina-typing
  path-and-base-paths : srs T lv -> lvs

  [(path-and-base-paths srs T x)
   [x]
   ]

  [(path-and-base-paths srs T (lv · f))
   [(lv · f) (path-and-base-paths srs T lv) ...]
   ]

  [(path-and-base-paths srs T (lv_b @ lv_i))
   [(lv_b @ lv_i) (path-and-base-paths srs T lv_b) ...]
   ]

  [(path-and-base-paths srs T (* lv))
   [(* lv) (path-and-base-paths srs T lv) ...]
   ]

  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; mut-loans £

(define-metafunction Patina-typing
  mut-loans : £ -> £

  [(mut-loans [(ℓ imm lv) loan ...])
   (mut-loans [loan ...])]

  [(mut-loans [(ℓ mut lv) loan ...])
   [(ℓ mut lv) loan_1 ...]
   (where [loan_1 ...] (mut-loans [loan ...]))]
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; lifetime-in-scope Λ ℓ
;;
;; Holds if the lifetime ℓ is in scope

(define-judgment-form
  Patina-typing
  #:mode     (lifetime-in-scope I I)
  #:contract (lifetime-in-scope Λ ℓ)

  [(side-condition (∈ ℓ (in-scope-lifetimes Λ)))
   --------------------------------------------------
   (lifetime-in-scope Λ ℓ)]

  )

(test-equal
 (judgment-holds (lifetime-in-scope [(a []) (b [])] a))
 #t)

(test-equal
 (judgment-holds (lifetime-in-scope [(a []) (b [])] b))
 #t)

(test-equal
 (judgment-holds (lifetime-in-scope [(a []) (b [])] c))
 #f)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; lifetime-bound Λ ℓ ty
;;
;; If this judgement holds, then the type `ty` is bound by the
;; lifetime ℓ.
;;
;; FIXME

(define-judgment-form
  Patina-typing
  #:mode     (lifetime-bound I I I )
  #:contract (lifetime-bound Λ ℓ ty)

  [--------------------------------------------------
   (lifetime-bound Λ ℓ ty)]

  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; unencumbered £ lv
;;
;; True if lv has not been loaned out.

(define-judgment-form
  Patina-typing
  #:mode     (unencumbered I lv)

  [(side-condition (∉ lv (loaned-paths £)))
   --------------------------------------------------
   (unencumbered £ lv)]

  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; owned-path srs T lv
;;
;; Holds if the path `lv` is an *owned path*.

(define-judgment-form
  Patina-typing
  #:mode     (owned-path I   I I )
  #:contract (owned-path srs T lv)

  [(where lv (owning-path srs T lv))
   --------------------------------------------------
   (owned-path srs T lv)]

  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; can-move-from

(define-judgment-form
  Patina-typing
  #:mode     (can-move-from I   I I I I I )
  #:contract (can-move-from srs T Λ £ ℑ lv)

  [;; Can only move from things we own:
   (owned-path srs ty lv)

   ;; Otherwise same as write:
   (can-write-to srs T Λ £ ℑ lv) 
   --------------------------------------------------
   (can-move-from srs T Λ £ ℑ lv)]

  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; owned-subpaths
;;
;; Elaborates from a owned path `lv` to a complete set of owned sub-paths,
;; as appropriate for the type of `lv`

(define-metafunction Patina-machine
  owned-subpaths : srs T lv -> [lv ...]
  
  [(owned-subpaths srs T lv)
   [lv lv_1 ... lv_2 ...]
   (where [lv_1 ...] (owned-subpaths1 srs T lv))
   (where [lv_2 ...] ,(flatten (term [(owned-subpaths1 srs T lv_1) ...])))
   ]
  )

(define-metafunction Patina-machine
  owned-subpaths1 : srs T lv -> [lv ...]

  [(owned-subpaths1 srs T lv)
   [(lv · f) ...]
   (where (struct s ℓs) (lvtype srs T lv))
   (where [f ...] (field-names srs s ℓs))]

  [(owned-subpaths1 srs T lv)
   [(* lv)]
   (where (~ ty) (lvtype srs T lv))]
  
  [(owned-subpaths1 srs T lv)
   []]
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; restricted-paths
;;
;; If a loan affects the lvalue `lv`, this function returns a set of
;; paths for `lv` that are *restricted* as a result. A path is
;; restricted if accessing it would violate the terms of the loan.
;;
;; More concretely, for a mutable loan of `lv`, `restricted-paths lv`
;; yields the set of paths that cannot be read or written as a result.
;; This includes not only `lv` itself but base paths of `lv`, because
;; reading those paths would either copy `lv` (as part of a larger
;; copy) or else create a second path to the same memory that was
;; borrowed. Similar concerns hold for writing.

(define-metafunction Patina-machine
  paths-restricted-by-loan-of : srs T lv -> lvs

  [(paths-restricted-by-loan-of srs T x)
   [x]
   ]

  [(paths-restricted-by-loan-of srs T (lv · f))
   [(lv · f) (paths-restricted-by-loan-of srs T Λ lv) ...]
   ]

  [(paths-restricted-by-loan-of srs T (lv_a @ lv_i))
   [(lv_a @ lv_i) (paths-restricted-by-loan-of srs T Λ lv_a) ...]
   ]

  [(paths-restricted-by-loan-of srs T (* lv))
   [(* lv) (paths-restricted-by-loan-of srs T Λ lv_a) ...]
   (where (~ ty) (lvtype srs T lv))
   ]

  ;; If we borrowed `*x` and `x` is a `&T`, that need not prevent us
  ;; from reading (or writing) `x`. I would eventually like to extend
  ;; this rule to handle writes to &mut borrowed lvalues too, but that
  ;; needs a bit more infrastructure and for time being I want to
  ;; model what rustc currently allows (or should allow).
  [(paths-restricted-by-loan-of srs T (* lv))
   [(* lv)]
   (where (& ℓ imm ty) (lvtype srs T lv))
   ]

  [(paths-restricted-by-loan-of srs T (* lv))
   [(* lv) (paths-restricted-by-loan-of srs T Λ lv_a) ...]
   (where (& ℓ mut ty) (lvtype srs T lv))
   ]

  )

(define-metafunction Patina-machine
  paths-restricted-by-loans : srs T £ -> lvs

  [(paths-restricted-by-loans srs T [(ℓ mq lv) ...])
   ,(flatten (term [(paths-restricted-by-loan-of srs T Λ lv) ...]))])

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; path-unique-for srs T Λ ℓ lv
;;
;; Holds if the path `lv` is a *unique path* during the lifetime ℓ.
;; This means that, during the lifetime ℓ, `lv` is the only
;; *accessible* path that would evaluate to that particular address.

(define-judgment-form
  Patina-typing
  #:mode     (path-unique-for I   I I I I )
  #:contract (path-unique-for srs T Λ ℓ lv)

  [--------------------------------------------------
   (path-unique-for srs T Λ ℓ x)]

  [(path-unique-for srs T Λ ℓ lv)
   --------------------------------------------------
   (path-unique-for srs T Λ ℓ (lv · f))]

  [(path-unique-for srs T Λ ℓ lv)
   --------------------------------------------------
   (path-unique-for srs T Λ ℓ (lv @ lv_1))]

  [(where (~ ty) (lvtype srs T lv))
   (path-unique-for srs T Λ ℓ lv)
   --------------------------------------------------
   (path-unique-for srs T Λ ℓ (* lv))]

  [(where (& ℓ' mut ty) (lvtype srs T lv))
   (lifetime-≤ Λ ℓ ℓ')
   (path-unique-for srs T Λ ℓ lv)
   --------------------------------------------------
   (path-unique-for srs T Λ ℓ (* lv))]

  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; path-freezable-for srs T Λ ℓ lv
;;
;; Holds if the path `lv` is a *freezable path* during the lifetime ℓ.
;; I am not quite sure how best to phrase this predicate in English.
;; Roughly speaking, the path-freezable-for predicte guarantees that the
;; memory which `lv` evaluates to will not be mutated during the
;; lifetime ℓ, assuming that the path `lv` is not itself assigned to
;; (if that is even possible). Often this corresponds to the underlying
;; memory referenced by `lv` but not always.
;;
;; Here are some interesting and representative examples:
;;
;; 1. `fn foo(x: &'a &'b mut T) -> &'a T { &**x }`
;;
;;     This example is legal because the path **x is freezable-for the
;;     lifetime 'a. If however the return type were `&'b T`, the
;;     example would be an error, because `**x` is not freezable-for
;;     'b. This is true *even though* we know that the memory will not yet
;;     be freed.
;;
;;     The reason is that, so long as the `&mut` *x is considered
;;     aliased, it cannot be changed. But that alias expires after 'a,
;;     and hence the memory in 'b would be considered mutable
;;     again.
;;
;; 2. `fn foo(x: &'a mut T) -> &'a T { &*x }`
;;
;;     In this case, the path `*x` is freezable-for the lifetime `'a`.
;;     The reason is that `x` is the only pointer that can mutate `*x`
;;     during the lifetime `'a`, and hence if we freeze `*x` we can be
;;     sure that the memory will not change until after `'a`.
;;
;; 3. `fn foo() -> &'a int { let x = 3; &x }`
;;
;;     Naturally, this case yields an error, but NOT because of
;;     freezable-for. This is crucial to the previous two examples, in
;;     fact. The idea here is that while the memory pointed at by `x`
;;     isn't valid for the entire lifetime 'a, if we ignore memory
;;     reuse, we can still say that it won't be assigned to. I'm not
;;     sure how best to express this part in English. Maybe this rule
;;     can be made more tidy. In any case, there is another predicate
;;     `path-outlives` that would catch this sort of error.

(define-judgment-form
  Patina-typing
  #:mode     (path-freezable-for I   I I I I )
  #:contract (path-freezable-for srs T Λ ℓ lv)

  [--------------------------------------------------
   (path-freezable-for srs T Λ ℓ x)]

  [(path-freezable-for srs T Λ ℓ lv)
   --------------------------------------------------
   (path-freezable-for srs T Λ ℓ (lv · f))]

  [(path-freezable-for srs T Λ ℓ lv)
   --------------------------------------------------
   (path-freezable-for srs T Λ ℓ (lv @ lv_1))]

  [(where (~ ty) (lvtype srs T lv))
   (path-freezable-for srs T Λ ℓ lv)
   --------------------------------------------------
   (path-freezable-for srs T Λ ℓ (* lv))]

  [(where (& ℓ' mut ty) (lvtype srs T lv))
   (lifetime-≤ Λ ℓ ℓ')
   (path-freezable-for srs T Λ ℓ lv)
   --------------------------------------------------
   (path-freezable-for srs T Λ ℓ (* lv))]

  [(where (& ℓ' imm ty) (lvtype srs T lv))
   (lifetime-≤ Λ ℓ ℓ')
   --------------------------------------------------
   (path-freezable-for srs T Λ ℓ (* lv))]

  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; can-access

(define-judgment-form
  Patina-typing
  #:mode     (can-access I   I I I I I )
  #:contract (can-access srs T Λ £ ℑ lv)

  [;; Data must be initialized:
   (lv-initialized ℑ (owning-path srs T lv))

   ;; The path lv cannot be restricted by a loan:
   ;;
   ;; This covers cases like these:
   ;;
   ;;    let x = &mut a.b.c; // restricts a, a.b, and a.b.c
   ;;    a.b = ...;          // would overwrite c as part
   ;;
   ;;    let x = &a.b.c;     // restricts a, a.b, and a.b.c
   ;;    a.b = ...;          // would overwrite c as part
   ;;
   ;;    let x = &mut a.b.c; // restricts a, a.b, and a.b.c
   ;;    let y = a.b;        // would read c as part
   (where [lv_r ...] (paths-restricted-by-loans srs T £_l))
   (side-condition (∉ lv lv_r))

   ;; Neither the path lv nor any base path of lv can be borrowed:
   ;;
   ;; This covers cases like this:
   ;;
   ;;    let x = &mut a;
   ;;    a.b = ...;          // would overwrite part of a
   ;;
   ;;    let x = &a;
   ;;    a.b = ...;          // would overwrite part of a
   ;;
   ;;    let x = &mut a;
   ;;    let y = a.b;        // would read part of a
   (where [lv_b ...] (path-and-base-paths lv))
   (unencumbered £_l lv_b) ...
   --------------------------------------------------
   (can-access srs T Λ £_l ℑ lv)]

  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; can-read-from

(define-judgment-form
  Patina-typing
  #:mode     (can-read-from I   I I I I I )
  #:contract (can-read-from srs T Λ £ ℑ lv)

  [;; Only mutable loans prevent reads:
   (can-access srs T Λ (mut-loans £) ℑ lv)
   --------------------------------------------------
   (can-read-from srs T Λ £ ℑ lv)]

  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; can-write-to

(define-judgment-form
  Patina-typing
  #:mode     (can-write-to I   I I I I I )
  #:contract (can-write-to srs T Λ £ ℑ lv)

  [;; All loans prevent writes:
   (can-access srs T Λ £ ℑ lv)
   --------------------------------------------------
   (can-write-to srs T Λ £ ℑ lv)]

  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; can-init

(define-judgment-form
  Patina-typing
  #:mode     (can-write-to I   I I I I )
  #:contract (can-write-to srs T Λ ℑ lv)

  [(lv-not-initialized ℑ x)
   --------------------------------------------------
   (can-init srs T Λ ℑ x)]

  [(lv-initialized ℑ lv)
   (lv-not-initialized ℑ (lv · f))
   --------------------------------------------------
   (can-init srs T Λ ℑ (lv · f))]

  [(lv-initialized ℑ lv)
   (lv-not-initialized ℑ (* lv))
   (where (~ ty) (lvtype srs T lv))
   --------------------------------------------------
   (can-init srs T Λ ℑ (* lv))]

  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; path-outlives

(define-judgment-form
  Patina-typing
  #:mode     (path-outlives I   I I I I )
  #:contract (path-outlives srs T Λ ℓ lv)

  [;; At present, we require that the borrow be for some lifetime that
   ;; is in scope. I'd like to lift this requirement in the future,
   ;; though I can't recall just what gets more complicated as a
   ;; result!
   (lifetime-in-scope Λ ℓ)

   ;; Determine from the path whether we be sure that the path outlives ℓ.
   (path-bound-by-lifetime srs T Λ ℓ lv)

   ;; Data cannot have a lifetime shorter than the loan ℓ.
   ;;
   ;; FIXME I feel like this check is unnecessary and implied by other
   ;; requirements. In other words, the memory has an ultimate local
   ;; variable in a block with lifetime ℓ, and presumably we wouldn't
   ;; allow that owner to gain access to data with some lifetime less
   ;; than ℓ. (Ah, perhaps this is what becomes complicated if we want
   ;; to allow data to be borrowed for a lifetime not currently in
   ;; scope, actually.)
   (where ty (lvtype srs T lv))
   (ty-bound-by-lifetime Λ ℓ ty)
   --------------------------------------------------
   (path-outlives srs T Λ £_l ℑ lv)]

  )

;; Holds if the memory directly referenced by `lv`
;; will outlive `ℓ`.
(define-judgment-form
  Patina-typing
  #:mode     (path-bound-by-lifetime I   I I I I )
  #:contract (path-bound-by-lifetime srs T Λ ℓ lv)

  [;; FIXME must determine lifetime of x, currently not found in any map
   --------------------------------------------------
   (path-bound-by-lifetime srs T Λ ℓ x)]

  [(path-bound-by-lifetime srs T Λ ℓ lv)
   --------------------------------------------------
   (path-bound-by-lifetime srs T Λ ℓ (lv · f))]

  [(path-bound-by-lifetime srs T Λ ℓ lv)
   --------------------------------------------------
   (path-bound-by-lifetime srs T Λ ℓ (lv @ lv_i))]

  [(where (~ ty) (lvtype srs T lv))
   (path-bound-by-lifetime srs T Λ ℓ lv)
   --------------------------------------------------
   (path-bound-by-lifetime srs T Λ ℓ (* lv))]

  [(where (& ℓ_lv mq ty) (lvtype srs T lv))
   (lifetime-≤ Λ ℓ ℓ_lv)
   --------------------------------------------------
   (path-bound-by-lifetime srs T Λ ℓ (* lv))]

  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; use-lv-ok and use-lvs-ok

(define-judgment-form
  Patina-typing
  #:mode     (use-lv-ok I   I I I I I  O  O)
  #:contract (use-ls-ok srs T Λ £ ℑ lv ty ℑ)

  ;; If `lv` is POD, it is not moved but rather copied.
  [(where ty (lvtype srs T lv))
   (can-read-from srs T Λ £ ℑ lv)
   (side-condition (ty-is-pod srs ty))
   --------------------------------------------------
   (use-lv-ok srs T Λ ℑ lv ty ℑ)]

  ;; Otherwise, each use deinitializes the value:
  [(where ty (lvtype srs T lv))
   (can-move-from srs T Λ £ ℑ lv)
   (side-condition (not (ty-is-pod srs ty)))
   --------------------------------------------------
   (use-lv-ok srs T Λ ℑ lv ty (\\ ℑ (owned-subpaths lv)))]
  )

(define-judgment-form
  Patina-typing
  #:mode     (use-lvs-ok I   I I I I I   O   O)
  #:contract (use-lvs-ok srs T Λ £ ℑ lvs tys ℑ)

  [--------------------------------------------------
   (use-lvs-ok srs T Λ ℑ [] [] ℑ)]

  [(use-lv-ok srs T Λ £ ℑ lv_0 ty_0 ℑ_0)
   (use-lvs-ok srs T Λ £ ℑ_0 [lv_1 ...] [ty_1 ...] ℑ_1)
   --------------------------------------------------
   (use-lvs-ok srs T Λ ℑ [lv_0 lv_1 ...] [ty_0 ty_1 ...] ℑ_1)]

  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; subtype
;;
;; FIXME

(define-judgment-form
  Patina-typing
  #:mode     (subtype I I I)
  #:contract (subtype Λ ty ty)

  [--------------------------------------------------
   (subtype Λ ty ty)]

  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; rv-ok

(define-judgment-form
  Patina-typing
  #:mode     (rv-ok I   I I I I I  O  O O)
  #:contract (rv-ok srs T Λ £ ℑ rv ty £ ℑ)

  ;; copy x -- deprecated
  [(where ty (lvtype srs T lv))
   (can-read-from srs T Λ £ ℑ lv)
   (side-condition (ty-is-pod srs ty))
   --------------------------------------------------
   (rv-ok srs T Λ £ ℑ (copy lv) ty £ ℑ)]

  ;; x
  [(use-lvs-ok srs T Λ £ ℑ [lv] [ty_out] ℑ_out)
   --------------------------------------------------
   (rv-ok srs T Λ £ ℑ lv ty_out £ ℑ_out)]

  ;; & ℓ imm lv
  [(can-read-from srs T Λ ℑ (mut-loans £) mq lv)
   (path-freezable-for srs T Λ ℓ lv)
   (path-outlives srs T Λ ℓ lv)
   --------------------------------------------------
   (rv-ok srs T Λ £ ℑ (& ℓ imm lv) (& ℓ imm ty) ℑ (∪ £ [ℓ mq lv]))]

  ;; & ℓ mut lv
  [(can-write-to srs T Λ ℑ (mut-loans £) mq lv)
   (path-unique-for srs T Λ ℓ lv)
   (path-outlives srs T Λ ℓ lv)
   --------------------------------------------------
   (rv-ok srs T Λ £ ℑ (& ℓ mut lv) (& ℓ mut ty) ℑ (∪ £ [ℓ mq lv]))]

  ;; struct s ℓs [lv ...]
  [(where [ty_f ...] (field-tys srs s [ℓ ...]))
   (use-lvs-ok srs T Λ £ ℑ [lv ...] [ty_a ...] ℑ_a)
   (lifetime-in-scope Λ ℓ) ...
   (subtype Λ ty_a ty_f) ...
   --------------------------------------------------
   (rv-ok srs T Λ £ ℑ (struct s [ℓ ...] [lv ...]) (struct s [ℓ ...]) £ ℑ_a)]

  ;; int
  [--------------------------------------------------
   (rv-ok srs T Λ £ ℑ number int £ ℑ)]

  ;; lv + lv
  [(use-lvs-ok srs T Λ £ ℑ [lv_1 lv_2] [int int] ℑ)
   --------------------------------------------------
   (rv-ok srs T Λ £ ℑ (lv_1 + lv_2) int ℑ £)]

  ;; (Some lv)
  [(use-lvs-ok srs T Λ £ ℑ [lv] [ty] ℑ_1)
   --------------------------------------------------
   (rv-ok srs T Λ £ ℑ (Some lv) (Option ty) £ ℑ_1)]

  ;; (None ty)
  [;; check ty well-formed
   --------------------------------------------------
   (rv-ok srs T Λ £ ℑ (None ty) (Option ty) £ ℑ)]

  ;; (vec ty lv ...)
  [;; check ty well-formed
   (where l (size [lv ...]))
   (use-lvs-ok srs T Λ £ ℑ [lv ...] [ty_lv ...] ℑ_1)
   (subtype Λ ty_lv ty) ...
   --------------------------------------------------
   (rv-ok srs T Λ £ ℑ (vec ty lv ...) (vec ty l) £ ℑ_1)]

  ;; (vec-len lv ...)
  [(where (& ℓ imm (vec ty olen)) (lvtype srs T lv))
   (can-read-from srs T Λ £ lv)
   --------------------------------------------------
   (rv-ok srs T Λ £ ℑ (vec-len lv) int £ ℑ)]

  ;; (pack lv ty)
  [(use-lvs-ok srs T Λ £ ℑ [lv] [ty] ℑ_1)
   --------------------------------------------------
   (rv-ok srs T Λ £ ℑ (pack lv ty) ty £ ℑ_1)]


  )

; Test you can copy an int and the value remains in the initialized set.
(test-equal
 (judgment-holds
  (rv-ok [] [[(i int)]] [] [] [i] (copy i) ty ℑ £)
  (ty ℑ £))
 (term ((int [i] []))))

; Test you cannot copy an uninitialized int.
(test-equal
 (judgment-holds
  (rv-ok [] [[(i int)]] [] [] [] (copy i) ty ℑ £)
  (ty ℑ £))
 (term ()))

; Test you cannot copy a ~int.
(test-equal
 (judgment-holds
  (rv-ok [] [[(i (~ int))]] [] [] [i] (copy i) ty ℑ £)
  (ty ℑ £))
 (term ()))

; ...But you can move it.
(test-equal
 (judgment-holds
  (rv-ok [] [[(i (~ int))]] [] [] [i] i ty ℑ £)
  (ty ℑ £))
 (term (((~ int) [] []))))

; ...Unless it is borrowed.
(test-equal
 (judgment-holds
  (rv-ok [] [[(i (~ int))]] [] [(i a [])] [i] i ty ℑ £)
  (ty ℑ £))
 (term ()))

; Test a simple, well-typed struct expression: `A { i }`
(test-equal
 (judgment-holds
  (rv-ok ,test-srs [[(i int)]] [] [] [i] (struct A [] [i]) ty ℑ £)
  (ty ℑ £))
 (term [((struct A []) [] [])]))

; Like previous, but with an invalid type for the field.
(test-equal
 (judgment-holds
  (rv-ok ,test-srs [[(i (~ int))]] [] [] [i] (struct A [] [i]) ty ℑ £)
  (ty ℑ £))
 (term ()))

; Like previous, but with an uninitialized `i`
(test-equal
 (judgment-holds
  (rv-ok ,test-srs [[(i int)]] [] [] [] (struct A [] [i]) ty ℑ £)
  (ty ℑ £))
 (term []))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; st-ok

(define-judgment-form
  Patina-typing
  #:mode     (st-ok I    I I I I I  O O)
  #:contract (st-ok prog T Λ £ ℑ st ℑ £)

  [(rv-ok srs T Λ £ ℑ rv ty_rv £_rv ℑ_rv)
   (can-init srs T Λ ℑ_rv lv)
   (subtype Λ ty_rv (lvtype srs T lv))
   --------------------------------------------------
   (st-ok (srs fns) T Λ £ ℑ (lv = rv) £_rv (∪ ℑ_rv [lv]))]

  [(rv-ok srs T Λ £ ℑ rv ty_rv (lv_rv ...) £_rv ℑ_rv)
   (can-write-to srs T Λ £_rv ℑ_rv lv)
   (subtype Λ ty_rv (lvtype srs T lv))
   --------------------------------------------------
   (st-ok (srs fns) T Λ ℜ ℑ (lv := rv) £_rv ℑ_rv)]

  [(use-lvs-ok srs T Λ £ ℑ [lv] [ty] ℑ_1)
   --------------------------------------------------
   (st-ok (srs fns) T Λ £ ℑ (free lv) £ ℑ_1)]

;;   [(bk-ok prog T_1 Λ ℜ ℑ (block ℓ vdecls sts) ℑ_1 ℜ_1)
;;    --------------------------------------------------
;;    (st-ok prog T Λ ℜ ℑ (block ℓ vdecls sts) ℑ_1 ℜ_1)]

  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; bk-ok
;; 
;; (define-judgment-form
;;   Patina-typing
;;   #:mode     (bk-ok I    I I I I I  O O)
;;   #:contract (bk-ok prog T Λ ℜ ℑ bk ℑ ℜ)
;; 
;;   [(where [vdecls_0 ...] T)
;;    (where T_1 [vdecls_1 vdecls_0 ...])
;;    --------------------------------------------------
;;    (bk-ok prog T Λ ℜ ℑ (block ℓ vdecls sts) ℑ_1 ℜ_1)]
;; 
;;   )
