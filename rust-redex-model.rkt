#lang racket

(require redex
         rackunit)


(define-language Patina
  (sr (struct s (l ...) ((f τ) ...)))
  (fn (fun g (l ...) ((x : τ) ...) bk))
  (bk (block l (let (x : τ) ...) st ...))
  (st (lv = rv) 
      (call g (l ...) (cm x) ...)
      bk)
  (lv x (o lv f) (* lv))
  (rv (cm x)    ;; use of local variable
      (lv o f)  ;; field projection
      (* lv)    ;; dereference
      (new s (l ...) (f cm x) ...) ;; struct constant
      (~ cm x)  ;; create owned box
      (& l mq lv) ;; borrow
      ())       ;; unit constant
  (cm copy move)
  (τ (struct-ty s l ...) ;; s<'l...>
     (~ τ)                 ;; ~t
     (& l mq τ)            ;; &'l mq t
     ())                   ;; ()
  (mq mut const imm)
  (x variable-not-otherwise-mentioned)
  (g variable-not-otherwise-mentioned)
  (s variable-not-otherwise-mentioned)
  (l variable-not-otherwise-mentioned)
  (f variable-not-otherwise-mentioned)
  )

;; definition of REF is *totally buried* in the paper.
;; also, it looks like TYPE is currently implicit

;; paper should specify that 'imm' is default mutability
;; qualifier. Maybe it does?

;; bug: subtype for ~ includes mq, unlike defn of ty

#|
// example from fig. 7
// really unsure about the unspecified bits:
// - type of p: which mq?
// - p assignment: which mq?
// should simple lv be available as rv?
fn borrow() { a: {
let mut v: (), u: ~(), p: &a ();
v = ();
u = ~(copy v);
p = &*u; // ...until here, same as Fig. ?? 
u = ~(copy v); // invalidates p
} }|#

;; check that the example matches the grammar:
(check-not-exn
 (lambda ()
   (redex-match
    Patina fn
    (term (fun borrow () () 
               (block a
                      (let (v : ())
                        (u : (~ ()))
                        (p : (& a imm ())))
                      (v = ())
                      (u = (~ copy v))
                      (p = (& z1 imm (* u)))
                      (u = (~ copy v))))))))




;; generate a random patina term
#;(generate-term Patina fn 5)



(define-extended-language Patina+Γ Patina
  [Γ · 
     (x : τ Γ)
     (l Γ)])

;; the subtype relation
(define-relation
  Patina+Γ
  subtype ⊆ τ × τ × Γ
  ;; implied by written rules (by induction on 
  ;; structure of types), subsumes several rules.
  [(subtype τ τ Γ)]
  [(subtype (& l_1 mq_1 τ_1) (& l_2 mq_2 τ_2) Γ)
   ;; contravariant in lifetimes
   (lifetime-<= l_2 l_1 Γ)
   ;; relation extracted from type rules:
   (mq-< mq_1 mq_2)
   (subtype τ_1 τ_2 Γ)]
  ;; special-case for mut: NB types are the same
  [(subtype (& l_1 mut τ) (& l_2 mut τ) Γ)
   ;; contravariant in lifetimes
   (lifetime-<= l_2 l_1 Γ)]
  [(subtype (~ τ_1) (~ τ_2) Γ)
   (subtype τ_1 τ_2 Γ)]
  )

;; an abstraction for the & rule
(define-relation
  Patina+Γ
  mq-< ⊆ mq × mq
  ;; anything is less than const
  [(mq-< mq const)]
  ;; imm is <= imm
  [(mq-< imm imm)]
  )

;; does l1 occur before l2 in the tenv or are they equal?
(define-relation
  Patina+Γ
  lifetime-<= ⊆ l × l × Γ
  ;; it might be more consistent to insist that it appears somewhere...
  [(lifetime-<= l_1 l_1 Γ)]
  [(lifetime-<= l_1 l_2 (x : τ Γ))
   (lifetime-<= l_1 l_2 Γ)]
  ;; l_1 < l_2 if l_1 is inside l_2, right?
  [(lifetime-<= l_1 l_2 (l_1 Γ))
   (tenv-contains? Γ l_2)])

;; does the type environment contain the lifetime l?
(define-relation
  Patina+Γ  
  tenv-contains? ⊆ Γ × l
  [(tenv-contains? (x : τ Γ) l)
   (tenv-contains? Γ l)]
  [(tenv-contains? (l Γ) l)])


;; it should be possible to make this work somehow...
#;(generate-term #:source bogo 5)

(check-false (term (tenv-contains? · la)))
(check-false (term (tenv-contains? (x : () (lb ·)) la)))
(check-true (term (tenv-contains? (x : () (lb ·)) lb)))

(check-false (term (lifetime-<= la lb (x : () (y : () ·)))))
(check-true (term (lifetime-<= la lb (x : () (la (y : () (lb ·)))))))
;; is this as desired?
(check-true (term (lifetime-<= la la ·)))


(check-true (term (mq-< imm imm)))
(check-false (term (mq-< const imm)))


(check-true (term (subtype () () ·)))
(check-true (term (subtype (& l1 imm   (& l3 const ()))
                           (& l1 const (& l4 const ()))
                           (l4 (l3 ·)))))
(check-true (term (subtype (& l1 imm   (& l3 mut ()))
                           (& l1 const (& l4 mut ()))
                           (l4 (l3 ·)))))
(check-false (term (subtype (& l1 imm   (& l3 mut ()))
                           (& l1 const ())
                           (l4 (l3 ·)))))
(check-false (term (subtype (& l1 imm   (& l4 mut ()))
                            (& l1 const (& l3 mut ()))
                            (l4 (l3 ·)))))
(check-false (term (subtype (& l1 mut (& l3 const ()))
                           (& l1 mut (& l4 const ()))
                           (l4 (l3 ·)))))

(check-true
 (term (subtype (~ (& l1 imm (& l3 const ()))) 
                (~ (& l1 imm (& l4 const ())))
                (l4 (l3 ·)))))
(check-false
 (term (subtype (~ (& l1 imm (& l4 const ()))) 
                (~ (& l1 imm (& l3 const ())))
                (l4 (l3 ·)))))

(check-true 
 (term (subtype (struct-ty foo l1 l2 l3)
                (struct-ty foo l1 l2 l3)
                (l4 (l3 ·)))))

(check-false
 (term (subtype (struct-ty foo l1 l2 l3)
                (struct-ty foo l1 l4 l3)
                (l4 (l3 ·)))))

