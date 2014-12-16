; Test suite for MPB.  This file runs MPB for a variety of cases,
; and compares it against known results from previous versions.  If the
; answers aren't sufficiently close, it exits with an error.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Some general setup and utility routines first:

(set! tolerance 1e-9) ; use a low tolerance to get consistent results

; keep track of some error statistics:
(define min-err infinity)
(define max-err 0)
(define max-abs-err 0)
(define sum-err 0)
(define sum-abs-err 0)
(define num-err 0)

; function to check if two results are sufficently close:
(define-param check-tolerance 1e-3)
(define (almost-equal? x y)
  (if (> (abs x) 1e-3)
      (let ((err (/ (abs (- x y)) (* 0.5 (+ (abs x) (abs y)))))
	    (abserr (abs (- x y))))
	(set! min-err (min min-err err))
	(set! max-err (max max-err err))
	(set! max-abs-err (max max-abs-err abserr))
	(set! num-err (+ num-err 1))
	(set! sum-err (+ sum-err err))
	(set! sum-abs-err (+ sum-abs-err abserr))))
  (or 
   (< (abs (- x y)) (* 0.5 check-tolerance (+ (abs x) (abs y))))
   (and (< (abs x) 1e-3) (< (abs (- x y)) 1e-3))))

; Convert a list l into a list of indices '(1 2 ...) of the same length.
(define (indices l)
  (if (null? l)
      '()
      (cons 1 (map (lambda (x) (+ x 1)) (indices (cdr l))))))

; Check whether the freqs returned by a run (all-freqs) match correct-freqs.
(define (check-freqs correct-freqs)
  (define (check-freqs-aux fc-list f-list ik)
    (define (check-freqs-aux2 fc f ib)
      (if (not (almost-equal? fc f))
	  (error "check-freqs: k-point " ik " band " ib " is "
		 f " instead of " fc)))
    (if (= (length fc-list) (length f-list))
	(map check-freqs-aux2 fc-list f-list (indices f-list))
	(error "check-freqs: wrong number of bands at k-point " ik)))
  (if (= (length correct-freqs) (length all-freqs))
      (begin
	(map check-freqs-aux correct-freqs all-freqs (indices all-freqs))
	(print "check-freqs: PASSED\n"))
      (error "check-freqs: wrong number of k-points")))

; checks whether list X and list Y are almost equal
(define (check-almost-equal X Y)
  (if (fold-left and true (map almost-equal? X Y))
      (print "check-almost-equal: PASSED\n")
      (error "check-almost-equal: FAILED\n" X Y)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(if (not (using-mpi?)) ; MPI code currently doesn't support 1d systems
(begin

; Use a lower tolerance for the 1d cases, since it is cheap; otherwise,
; the Bragg-sine case perennially causes problems.
(set! tolerance (/ tolerance 10000))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; First test: a simple 1d Bragg mirror:

(print
 "**************************************************************************\n"
 " Test case: 1d quarter-wave stack.\n"
 "**************************************************************************\n"
)

(set! geometry (list (make cylinder (material (make dielectric (epsilon 9.0)))
			   (center 0) (axis 1)
			   (radius infinity) (height 0.25))))
(set! k-points (interpolate 4 (list (vector3 0 0 0) (vector3 0.5 0 0))))
(set! grid-size (vector3 32 1 1))
(set! num-bands 8)

(let ((correct-freqs '((0.0 0.666384282528928 0.666667518031881 1.33099337665679 1.33336087672839 1.99161980173015 2.00024302642565 2.6450937852083) (0.0574931097997446 0.608787973096119 0.724373977055668 1.2735966394103 1.39097797892597 1.93584941706027 2.05633589084836 2.59377005482918) (0.113352271592983 0.552761237115776 0.780756082813777 1.21672824612875 1.44856381682192 1.87756171149864 2.11568713317692 2.53392260905135) (0.164802158007456 0.501201811770545 0.832987385247272 1.16417795261225 1.50250265212664 1.82314371802974 2.17224997337128 2.47690271740002) (0.205536502065922 0.460405353660882 0.8747810869492 1.12220337812548 1.54664162749105 1.77873062187023 2.22033216569935 2.42854622021095) (0.22245099319197 0.443470718153721 0.89236781440248 1.10455805248897 1.56579373692671 1.75948932731251 2.24248043100853 2.40631190043537))))

  (run-tm)
  (check-freqs correct-freqs)
  
  (run-te)
  (check-freqs correct-freqs))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Second test: a less-simple 1d Bragg mirror, consisting of a sinusoidally
; varying dielectric index (see also bragg-sine.ctl):

(print
 "**************************************************************************\n"
 " Test case: 1d sinusoidal Bragg mirrors.\n"
 "**************************************************************************\n"
)

(let ((pi (* 4 (atan 1)))) ; 3.14159...
  (define (eps-func p)
    (make dielectric (index (+ 2 (cos (* 2 pi (vector3-x p)))))))
  (set! default-material (make material-function (material-func eps-func))))

(set! k-points (interpolate 9 (list (vector3 0 0 0) (vector3 0.5 0 0))))
(set! grid-size (vector3 32 1 1))
(set! num-bands 8)

(run-tm)
(check-freqs '((0.0 0.460648275218079 0.542427739817 0.968586586361068 1.01617062660004 1.48337333794755 1.48386583676098 1.96763768634053) (0.0231424888788602 0.454293827620926 0.548894464606965 0.958360293771355 1.02641972845204 1.45913774058533 1.50811173706602 1.94948827608003) (0.0462090787082577 0.439084320039512 0.564452582533386 0.938267239403995 1.04658249131212 1.43467215953867 1.53260886786687 1.92547645623973) (0.0691102159040715 0.420015536860369 0.584144708540882 0.915749746086578 1.06922078451581 1.41022612312792 1.55710983305974 1.90110410737745) (0.0917238673443258 0.399480768741237 0.60565316278248 0.892483769139075 1.09266692571585 1.38580829656309 1.58161025389159 1.87664635327897) (0.113863114251085 0.378567678109852 0.628026307077094 0.868958449423545 1.11644695897109 1.3614327391061 1.60610415581645 1.85216493367767) (0.135212561098235 0.357979431767488 0.650804940461757 0.845399327507094 1.14036437789844 1.33712597279413 1.63058104368944 1.82768870377694) (0.155193837618337 0.338479349371984 0.673671347997618 0.822003372220962 1.16428444411062 1.31294698795159 1.65501798584125 1.80324819761608) (0.172679547014293 0.321289854992633 0.696193190997784 0.799137496016584 1.18800188305626 1.28906327514362 1.67934881274624 1.77891315965595) (0.185502873728775 0.308627942742938 0.717034417258616 0.778101847588796 1.21076249234602 1.26620930567935 1.70326114132094 1.75499775017206) (0.19041596916807 0.303766163770654 0.728590051056375 0.766483258741006 1.22530241888082 1.25163924613769 1.72099865592632 1.73725912578794)))

(set! default-material air) ; don't screw up later tests

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(set! tolerance (* tolerance 10000))

)) ; if (not (using-mpi?))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Square lattice of dielectric rods in air.

(print
 "**************************************************************************\n"
 " Test case: Square lattice of dielectric rods in air.\n"
 "**************************************************************************\n"
)

(set! geometry (list
		(make cylinder (material (make dielectric (epsilon 11.56))) 
		      (center 0 0) (radius 0.2) (height infinity))))
(set! k-points (interpolate 4 (list (vector3 0) (vector3 0.5)
				    (vector3 0.5 0.5 0) (vector3 0))))
(set! grid-size (vector3 32 32 1))
(set! num-bands 8)

(run-te)
(check-freqs '((0.0 0.561945334557385 0.780842812331228 0.780846098412592 0.924371683163949 1.00803985129792 1.00804088731802 1.09858623956652) (0.0897997798994076 0.560209896469707 0.767785350870472 0.782438231618754 0.912603067546361 1.00888633849104 1.00949114803277 1.12115474664388) (0.178852773321546 0.553300983639649 0.732522222968759 0.786672449175983 0.890463105855642 1.01385729138557 1.02078013833592 1.11300646463179) (0.266123594110195 0.534865350840295 0.689376138533469 0.792049548816113 0.872925911023147 1.02090314736827 1.04285404891473 1.10753383632769) (0.349588020537016 0.494779669995165 0.658508223213229 0.796523676734899 0.862683642813515 1.02898182530566 1.07043694197557 1.10003079693163) (0.413345586803412 0.44462291351553 0.648672217588454 0.798265471046059 0.859327463282679 1.03311041395003 1.09580214986717 1.09741680977047) (0.424298362126911 0.44898279373346 0.644548562548272 0.802551148059984 0.854853159661748 0.98983998591444 1.0583076027211 1.11679157683255) (0.455353836640927 0.461160511700901 0.633230253238328 0.814782424365419 0.834250744952672 0.934557961696952 1.01274334726807 1.12367050454956) (0.478427219924468 0.501912134249683 0.617449702512683 0.784489069111248 0.833710248078536 0.906540901997911 0.967733581444411 1.1263583529554) (0.495604528258234 0.556867480138193 0.601739184739058 0.720584183505631 0.858431813314025 0.897771643330533 0.92661062844362 1.12761853567986) (0.503605801531701 0.594344024613055 0.59435663953178 0.679388741318615 0.883664739567964 0.895781768469706 0.895786874556172 1.12801276576574) (0.474670773656218 0.549917137140298 0.608031881017845 0.745034531026827 0.848354751485403 0.895854164182374 0.945890643267912 1.12708247876502) (0.373253932819571 0.543225052446258 0.646250803261438 0.817389372081735 0.830457382271798 0.896516227567732 1.01760084433849 1.12197791661875) (0.252369333718973 0.551073128162047 0.700804337123788 0.797551602017551 0.899585769590366 0.903389586014203 1.08791421563576 1.10099000357684) (0.126940001741566 0.558853684776988 0.755651182474766 0.785047154907932 0.909884122992341 0.968812657472461 1.04813919691317 1.11332213355591) (0.0 0.561945334407731 0.780842812401179 0.780846098384021 0.924371683195103 1.00803985129514 1.00804088729554 1.09858622997793)))

(run-tm)
(check-freqs '((0.0 0.550336075492761 0.561337783494192 0.561339793996441 0.822948013585295 0.868841613389014 0.965325380929893 1.08937760109445) (0.0651416429431535 0.525003695654183 0.561884878000649 0.586306893982008 0.823535977020037 0.86734647097958 0.954632345309176 1.05687677175817) (0.127664746818747 0.493649813919317 0.563322581824471 0.617311826620811 0.822736862854134 0.863529964061771 0.92430556209052 1.03882168368046) (0.184046514295327 0.461592151644409 0.565121689802102 0.651396635807459 0.810838592407438 0.85898411247184 0.892949156581082 1.03589199660828) (0.227778015582534 0.433360712061513 0.566595731512458 0.689044651877333 0.778791875677485 0.855425103295414 0.879398204894174 1.0387432995892) (0.245808974576747 0.420657338406186 0.56716328782128 0.720091820469093 0.747202991063479 0.854090458576806 0.877011871859037 1.04079703189466) (0.249298773583017 0.427307623035431 0.560220797848635 0.718025037316212 0.756122437610169 0.855013330357386 0.877106455296421 1.02916965498279) (0.258693333199135 0.445540869703809 0.543385384840764 0.711697647242147 0.779350400764203 0.858135812263486 0.877357018542926 1.00092092539592) (0.270962613899996 0.470322466744217 0.524052873443864 0.701396122540261 0.810963308664218 0.864393838558208 0.877683037781189 0.965108093819696) (0.281613643862846 0.493207050642694 0.508823220586706 0.68996057277849 0.846784814196112 0.87459516255628 0.878068231243395 0.926580909129451) (0.285905779127161 0.502981364580489 0.502983097838737 0.684476386658726 0.874359380527121 0.883317372585053 0.883317410406254 0.892993349560143) (0.276088805107277 0.491352389673393 0.508683441988827 0.692579899252015 0.839723261134077 0.85643142702439 0.907218621287156 0.907347258076394) (0.240239034783233 0.479230170582085 0.523498859086802 0.685361670368096 0.829265933706741 0.840450969771508 0.910791381218572 0.941595252480836) (0.175240325825588 0.488533364028353 0.541560691215046 0.647509833455847 0.83001959727719 0.850443167942857 0.922657201444286 0.983924775906362) (0.0915258938978901 0.516393376876295 0.555923804221748 0.60121063231939 0.824561228580069 0.865290375816656 0.948411582724858 1.03526242687651) (0.0 0.550336075497221 0.561337783491839 0.561339793993807 0.822948013590914 0.868841613389918 0.965325380904055 1.08937790223254)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Using the targeted solver to find a defect state in a 5x5 triangular
; lattice of rods.

(print
 "**************************************************************************\n"
 " Test case: 3x3 triangular lattice of rods in air, dipole defect states.\n"
 "**************************************************************************\n"
)

(if (not force-mu?) ; targeted solver doesn't handle mu yet
    (begin
      (set! geometry-lattice (make lattice (size 3 3 1)
                                   (basis1 (/ (sqrt 3) 2) 0.5)
                                   (basis2 (/ (sqrt 3) 2) -0.5)))
      (set! k-points (list (vector3 0 0.5 0))) ; K
      (set! geometry (list
                      (make cylinder (material (make dielectric (epsilon 12))) 
                            (center 0 0) (radius 0.2) (height infinity))))
      (set! geometry (geometric-objects-lattice-duplicates geometry))
      (set! geometry (append geometry 
                             (list (make cylinder (center 0 0 0) 
                                         (radius 0.33) (height infinity)
                                         (material (make dielectric (epsilon 12)))))))
      (set! grid-size (vector3 (* 16 5) (* 16 5) 1))
      (set! num-bands 2)
      (set! target-freq 0.35)
      (run-tm)
      
      (let ((ct-save check-tolerance))
        (set! check-tolerance (* ct-save 10))
        (check-freqs '((0.33627039929402 0.338821383601027)))
        (set! check-tolerance ct-save))
      
      (set! target-freq 0)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(print
 "**************************************************************************\n"
 " Test case: fcc lattice of air spheres in dielectric.\n"
 "**************************************************************************\n"
)

(set! geometry-lattice (make lattice
			 (basis1 0 1 1)
			 (basis2 1 0 1)
			 (basis3 1 1 0)))
(set! k-points (interpolate 1 (list
			       (vector3 0 0.5 0.5)            ; X
			       (vector3 0 0.625 0.375)        ; U
			       (vector3 0 0.5 0)              ; L
			       (vector3 0 0 0)                ; Gamma
			       (vector3 0 0.5 0.5)            ; X
			       (vector3 0.25 0.75 0.5)        ; W
			       (vector3 0.375 0.75 0.375))))  ; K
(set! geometry (list (make sphere (center 0) (radius 0.5) (material air))))
(set! default-material (make dielectric (epsilon 11.56)))
(set! grid-size (vector3 16 16 16))
(set! mesh-size 5)
(set! num-bands 10)
(run)
(check-freqs '((0.368982508580386 0.370414874154296 0.38054839838165 0.381357051945723 0.491513720029372 0.51121392863688 0.521363342497417 0.522861193744798 0.592667676918319 0.661690514141366) (0.367020237266256 0.375797592625609 0.382773925549089 0.385461932700734 0.469710555381094 0.505345355926352 0.52281600926083 0.529848937216978 0.608024611885665 0.645331772905374) (0.356148094562699 0.378821717883782 0.391057032153736 0.399470971405211 0.437323856255036 0.493905903117348 0.526668553005108 0.539639058437665 0.63363930938116 0.640377586058671) (0.322331263143627 0.329883020473848 0.39633819564794 0.399292349978453 0.461110211027844 0.513251479625681 0.532637635779923 0.545141046814197 0.628477949553707 0.641406165032021) (0.306208216753111 0.30720983871744 0.386354358807912 0.387814801657265 0.489971009772797 0.535466222156093 0.536375504069675 0.538139640206077 0.621853815224684 0.625576237106134) (0.178859734457415 0.179320605610199 0.472011449233806 0.47415160932512 0.50199374441813 0.535090816560177 0.537373496001262 0.540138391993461 0.621420370144011 0.624472560227568) (0.0 0.0 0.517352332947689 0.520002862413723 0.52000998488147 0.543793108009828 0.543804563668257 0.54611949003285 0.609965221810339 0.610911592716707) (0.206171409773412 0.206578521564303 0.471831191008671 0.473583292330337 0.505015743288147 0.52608434561707 0.529675644154018 0.531247845312004 0.601961712578954 0.651911316476201) (0.368982508607754 0.370414874177744 0.38054839846607 0.381357051990387 0.491513720038249 0.511213928597604 0.521363342567513 0.522861193724753 0.5926676768892 0.661690566687818) (0.370855082942356 0.375535044990879 0.383957530115669 0.390387285130789 0.46143300060012 0.500837390758211 0.504196072793132 0.548295643991495 0.619261917910806 0.634962775719668) (0.372209234884998 0.384598603598355 0.384713321057366 0.407868853041212 0.433282510618956 0.489638974802283 0.491154274377333 0.566045188346111 0.623766417122018 0.651592170483669) (0.362554935689522 0.380879434108421 0.388519147314381 0.403695419934365 0.4364044517563 0.492285144668654 0.504428237945514 0.558399557280067 0.630652658823279 0.642705425888956) (0.357412643505187 0.378344354884614 0.389830616765953 0.400444783721239 0.436214944650087 0.493813244349865 0.528292157574522 0.540102363490965 0.635409833339297 0.641130580611554)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(print
 "**************************************************************************\n"
 " Test case: simple cubic lattice with anisotropic dielectric.\n"
 "**************************************************************************\n"
)

(set! geometry-lattice (make lattice))
(set! default-material air)
(set! k-points (list (vector3 0) (vector3 0.5)
		     (vector3 0.5 0.5) (vector3 0.5 0.5 0.5)))
(set! grid-size (vector3 16 16 16))
(set! mesh-size 5)
(define hi-all (make dielectric (epsilon 12)))
(define hi-x (make dielectric-anisotropic (epsilon-diag 12 1 1)))
(define hi-y (make dielectric-anisotropic (epsilon-diag 1 12 1)))
(define hi-z (make dielectric-anisotropic (epsilon-diag 1 1 12)))
(set! geometry
	(list (make block (center 0) (size 0.313 0.313 1) (material hi-z))
	      (make block (center 0) (size 0.313 1 0.313) (material hi-y))
	      (make block (center 0) (size 1 0.313 0.313) (material hi-x))
	      (make block (center 0) (size 0.313 0.313 0.313) 
		    (material hi-all))))
(set! num-bands 3)
(run)
(check-freqs '((0.0 0.0 0.546634963647193) (0.259951207183097 0.259951258670471 0.444658075510584) (0.300692330235002 0.345673935773948 0.497692646240215) (0.362782432577119 0.362782474830613 0.502236936705387)))

(print
 "*******************************************************************************\n"
 " Test case: group velocity in simple cubic lattice with anisotropic dielectric.\n"
 "*******************************************************************************\n"
)
(set! k-points (list (vector3 0.12 0.34 0.41)))
(run)
(let ((v (compute-group-velocity-component (vector3 1 2 3))))
  (check-almost-equal v (map (lambda (b) (compute-1-group-velocity-component (vector3 1 2 3) b))
                             (arith-sequence 1 1 num-bands)))
  (check-almost-equal v '(0.202671224992983 0.310447990695762 -0.0480795046912859)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(display-eigensolver-stats)
(print "Relative error ranged from " min-err " to " max-err
	      ", with a mean of " (/ sum-err num-err) "\n")
(print "Absolute error ranged to " max-abs-err
	      ", with a mean of " (/ sum-abs-err num-err) "\n")
(print "PASSED all tests.\n")
