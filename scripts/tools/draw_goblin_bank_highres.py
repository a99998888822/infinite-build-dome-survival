"""Original code-drawn illustration for review; no image-model inference.

Render curved vector artwork directly at review resolution. No low-resolution
source, upscaling, quantization, pixel cleanup, or production replacement.
Requires Pillow and resvg_py; --renderer-dir may point at an isolated install.
"""
from pathlib import Path
import argparse
import io
import json
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/previews/goblin_bank_highres"

DEFS = '''<defs>
 <linearGradient id="skin" x1="0" y1="0" x2=".85" y2="1" gradientUnits="objectBoundingBox"><stop stop-color="#b6bd78"/><stop offset=".35" stop-color="#929e5e"/><stop offset=".7" stop-color="#6b8050"/><stop offset="1" stop-color="#394f3c"/></linearGradient>
 <radialGradient id="face" cx=".34" cy=".25" r=".82"><stop stop-color="#c3c98a"/><stop offset=".45" stop-color="#a0ad69"/><stop offset=".82" stop-color="#6e8452"/><stop offset="1" stop-color="#4b6242"/></radialGradient>
 <linearGradient id="innerEar" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#797948"/><stop offset=".6" stop-color="#666944"/><stop offset="1" stop-color="#a0a56a"/></linearGradient>
 <linearGradient id="nose" x1="0" y1="0" x2=".6" y2="1"><stop stop-color="#c3c991"/><stop offset=".58" stop-color="#a4ae71"/><stop offset="1" stop-color="#6b8353"/></linearGradient>
 <linearGradient id="coat" x1="0" y1="0" x2=".9" y2="1"><stop stop-color="#64716b"/><stop offset=".42" stop-color="#424e49"/><stop offset="1" stop-color="#242f2d"/></linearGradient>
 <linearGradient id="lapel" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#8c9180"/><stop offset=".45" stop-color="#657169"/><stop offset="1" stop-color="#3d4b45"/></linearGradient>
 <linearGradient id="shirt" x1="0" y1="0" x2=".8" y2="1"><stop stop-color="#e7ddbb"/><stop offset=".5" stop-color="#bfb89c"/><stop offset="1" stop-color="#8b937e"/></linearGradient>
 <linearGradient id="tie" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#a37649"/><stop offset=".45" stop-color="#7c4a34"/><stop offset="1" stop-color="#4a342c"/></linearGradient>
 <linearGradient id="gold" x1="0" y1="0" x2=".9" y2="1"><stop stop-color="#ecdaa0"/><stop offset=".35" stop-color="#bc9a57"/><stop offset=".7" stop-color="#826439"/><stop offset="1" stop-color="#524930"/></linearGradient>
 <linearGradient id="woodTop" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#8a6948"/><stop offset=".5" stop-color="#705139"/><stop offset="1" stop-color="#4a372b"/></linearGradient>
 <linearGradient id="woodFront" x1="0" y1="0" x2=".1" y2="1"><stop stop-color="#6d4c34"/><stop offset=".55" stop-color="#4b3429"/><stop offset="1" stop-color="#322721"/></linearGradient>
 <linearGradient id="woodInset" x1="0" y1="0" x2=".85" y2="1"><stop stop-color="#45372a"/><stop offset=".5" stop-color="#655037"/><stop offset="1" stop-color="#392f25"/></linearGradient>
 <linearGradient id="woodLeg" x1="0" y1="0" x2="1" y2="0"><stop stop-color="#2d2921"/><stop offset=".25" stop-color="#725239"/><stop offset=".5" stop-color="#59402e"/><stop offset="1" stop-color="#32291f"/></linearGradient>
 <linearGradient id="leather" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#69735a"/><stop offset=".6" stop-color="#354c40"/><stop offset="1" stop-color="#24352d"/></linearGradient>
 <linearGradient id="paper" x1="0" y1="0" x2=".4" y2="1"><stop stop-color="#ece0b5"/><stop offset="1" stop-color="#b3a17b"/></linearGradient>
 <radialGradient id="eye"><stop stop-color="#f0db88"/><stop offset=".7" stop-color="#c3b965"/><stop offset="1" stop-color="#7e8950"/></radialGradient>
</defs>'''

HANDS = '''<g id="left-hand" stroke="#394d36" stroke-width="3.5" stroke-linejoin="round">
 <path d="M281 755 Q307 750 323 777 L316 811 Q294 817 275 801Z" fill="url(#shirt)"/>
 <path d="M293 773 C318 754 347 757 368 774 Q386 788 382 813 C367 834 323 842 299 822 Q281 806 293 773Z" fill="url(#skin)"/>
 <path d="M302 800 C294 797 283 801 278 814 L270 836 Q269 847 280 850 Q289 850 294 838 L308 820" fill="url(#skin)"/>
 <path d="M310 801 C305 814 310 841 315 853 Q321 864 330 858 C337 853 327 824 331 810" fill="url(#skin)"/>
 <path d="M332 798 C330 817 335 852 342 864 Q348 873 357 867 C364 861 348 825 353 809" fill="url(#skin)"/>
 <path d="M355 799 C357 817 361 843 371 854 Q378 861 385 854 C390 848 372 823 375 806" fill="url(#skin)"/>
 <path d="M375 799 C384 808 392 826 401 831 Q409 834 413 827 C417 820 398 801 387 791 Q380 784 370 783" fill="url(#skin)"/>
 <path d="M300 783 Q315 769 331 774 M340 773 Q354 772 362 781 M304 814 L299 831 M319 831 L327 833 M342 840 L351 841 M370 832 L376 832" fill="none" stroke="#bcc189" stroke-width="3" opacity=".66" stroke-linecap="round"/>
 <path d="M318 846 Q322 842 327 846 L330 854 Q326 858 321 855Z M344 854 Q348 850 353 854 L357 862 Q351 867 347 862Z M374 844 Q378 840 382 844 L386 850 Q382 855 378 851Z M400 821 Q404 818 407 820 L410 826 Q406 830 403 827Z" fill="#bac295" stroke="#657c51" stroke-width="1.7"/>
 <path d="M303 791 Q316 797 325 791 M335 789 Q347 797 355 790 M323 814 Q335 817 342 812" fill="none" stroke="#576f48" stroke-width="2.2" opacity=".7"/>
</g>
<use href="#left-hand" transform="translate(1024 0) scale(-1 1)"/>
'''

CHARACTER = '''<g stroke-linecap="round" stroke-linejoin="round">
 <!-- Tailored silhouette and seated forearms. -->
 <path d="M398 560 C345 566 274 596 244 637 C218 689 222 815 247 890 Q510 927 775 890 C800 815 805 689 780 637 Q739 582 626 560Z" fill="url(#coat)" stroke="#242f2c" stroke-width="7"/>
 <path d="M311 603 C243 613 195 658 179 720 Q166 765 188 803 L256 826 L313 760 Q279 724 321 674Z" fill="url(#coat)" stroke="#29372f" stroke-width="6"/>
 <path d="M713 603 C781 613 829 658 845 720 Q858 765 836 803 L768 826 L711 760 Q745 724 703 674Z" fill="url(#coat)" stroke="#29372f" stroke-width="6"/>
 <path d="M207 713 Q224 667 261 647 M191 763 Q221 742 256 758 M213 790 L255 802 M817 713 Q800 667 763 647 M833 763 Q803 742 768 758" fill="none" stroke="#889182" stroke-width="4" opacity=".47"/>
 <path d="M217 791 Q251 787 281 752 L299 773 L280 815 L257 831Z M807 791 Q773 787 743 752 L725 773 L744 815 L767 831Z" fill="#26382f" stroke="#9a997a" stroke-width="3"/>
 <path d="M419 548 L609 548 L617 618 Q510 669 412 618Z" fill="url(#skin)" stroke="#3d543c" stroke-width="5"/>
 <path d="M429 555 Q511 602 600 553 L598 591 Q522 636 431 588Z" fill="#415c40" opacity=".57"/>
 <path d="M421 596 Q511 628 606 596 L571 899 L448 899Z" fill="url(#shirt)" stroke="#6f7763" stroke-width="4"/>
 <path d="M426 601 L493 639 L465 705 L399 635Z M603 601 L529 639 L564 705 L625 635Z" fill="url(#shirt)" stroke="#8e927a" stroke-width="3"/>
 <path d="M500 641 L529 641 L540 674 L518 694 L491 673Z" fill="url(#tie)" stroke="#60442d" stroke-width="3"/>
 <path d="M506 686 L526 686 L548 848 L516 885 L483 846Z" fill="url(#tie)" stroke="#59422f" stroke-width="4"/>
 <path d="M509 704 L513 841" stroke="#cc9961" stroke-width="3" opacity=".5"/>
 <path d="M399 587 L339 610 L327 705 L364 703 L348 734 L450 887 L426 693 L458 673Z" fill="url(#lapel)" stroke="#26362f" stroke-width="5"/>
 <path d="M625 587 L685 610 L697 705 L660 703 L676 734 L575 887 L598 693 L567 673Z" fill="url(#lapel)" stroke="#26362f" stroke-width="5"/>
 <path d="M401 599 L445 672 L416 695 L441 852 M623 599 L580 672 L608 695 L584 852" fill="none" stroke="#bec0a4" stroke-width="2.5" opacity=".65"/>
 <path d="M355 766 L409 806 M667 766 L613 806" stroke="#2c3d33" stroke-width="4"/>
 <path d="M639 775 L687 764 L690 780 L639 790Z" fill="#26382e" stroke="#768575" stroke-width="2"/>
 <path d="M652 775 L654 758 L666 765 L676 753 L678 770Z" fill="#c4bba0" stroke="#777e69" stroke-width="2"/>
 <circle cx="455" cy="860" r="7" fill="url(#gold)" stroke="#28392e" stroke-width="2"/>
 <!-- Long ears with sculpted rims and a restrained warm inner fold. -->
 <path d="M349 255 C302 268 233 251 124 219 Q141 254 170 277 C203 303 218 357 260 383 Q298 400 341 366Z" fill="url(#skin)" stroke="#344c36" stroke-width="7"/>
 <path d="M675 255 C722 268 791 251 900 219 Q883 254 854 277 C821 303 806 357 764 383 Q726 400 683 366Z" fill="url(#skin)" stroke="#344c36" stroke-width="7"/>
 <path d="M169 245 Q248 280 320 277 L313 350 Q276 322 249 345 Q227 299 169 245Z M855 245 Q776 280 704 277 L711 350 Q748 322 775 345 Q797 299 855 245Z" fill="url(#innerEar)" stroke="#58663e" stroke-width="3"/>
 <path d="M169 246 Q244 268 314 281 M855 246 Q780 268 710 281" stroke="#d0cb8e" stroke-width="4" fill="none" opacity=".72"/>
 <path d="M263 315 Q289 297 315 327 M761 315 Q735 297 709 327" stroke="#4e603e" stroke-width="4" fill="none"/>
 <!-- Bald head, jaw and cheek planes. -->
 <path d="M332 303 C312 257 312 200 340 159 C374 105 433 82 501 83 C585 78 653 107 683 159 C712 208 707 260 689 304 C718 340 708 402 682 445 C659 493 619 539 569 563 Q511 589 454 564 C405 550 365 517 341 472 C310 438 302 381 322 342Z" fill="url(#face)" stroke="#354c36" stroke-width="7"/>
 <path d="M356 179 C392 132 444 114 510 115 Q599 111 653 170" fill="none" stroke="#dce0a4" stroke-width="6" opacity=".6"/>
 <path d="M680 217 Q680 274 665 319 Q695 351 671 403 Q649 434 643 474 Q599 552 536 560 Q616 557 658 499 Q695 446 704 386 Q710 342 689 304Z" fill="#4e6b46" opacity=".48"/>
 <path d="M339 364 Q362 338 401 357 L420 416 Q373 436 350 413Z" fill="#b2bd7b" opacity=".65"/>
 <path d="M683 350 Q651 337 625 358 L610 409 Q655 427 676 398Z" fill="#7d945b"/>
 <path d="M369 418 Q397 412 419 444 M650 413 Q624 416 605 443" stroke="#637d4c" stroke-width="5" fill="none"/>
 <!-- Eye sockets, gold-green irises, lids and uneven brows. -->
 <path d="M350 300 Q395 268 467 301 Q478 334 449 358 Q391 375 355 344Z M558 297 Q613 267 674 291 Q692 323 664 351 Q609 364 572 339Z" fill="#5b7147"/>
 <path d="M358 316 Q405 288 465 316 Q445 348 405 345 Q377 343 358 316Z" fill="#d3cd90" stroke="#405e3b" stroke-width="4"/>
 <path d="M566 307 Q616 282 674 305 Q653 338 617 338 Q586 336 566 307Z" fill="#d5cf8d" stroke="#405e3b" stroke-width="4"/>
 <ellipse cx="428" cy="321" rx="17" ry="24" fill="url(#eye)" stroke="#637242" stroke-width="3"/>
 <ellipse cx="638" cy="311" rx="17" ry="25" fill="url(#eye)" stroke="#637242" stroke-width="3"/>
 <ellipse cx="432" cy="322" rx="6.5" ry="17" fill="#263b2b"/>
 <ellipse cx="642" cy="312" rx="6.5" ry="18" fill="#263b2b"/>
 <circle cx="426" cy="314" r="4" fill="#fff1ba"/><circle cx="636" cy="304" r="4" fill="#fff1ba"/>
 <path d="M352 308 Q405 293 467 310 L467 316 Q411 308 360 325Z M564 300 Q620 282 676 298 L675 307 Q619 297 570 316Z" fill="#91a568" stroke="#566f43" stroke-width="2"/>
 <path d="M351 297 Q380 270 423 277 Q458 279 479 304 Q417 288 356 308Z M549 302 Q578 274 620 270 Q653 268 680 285 L677 294 Q614 283 552 312Z" fill="#425b39"/>
 <path d="M363 289 Q414 265 464 295 M562 294 Q616 268 670 282" fill="none" stroke="#788c50" stroke-width="3"/>
 <path d="M373 352 Q415 374 455 350 M586 348 Q626 366 661 344" fill="none" stroke="#536e42" stroke-width="3"/>
 <path d="M381 361 Q416 377 444 361 M596 356 Q630 367 652 354" fill="none" stroke="#c0c987" stroke-width="2.5" opacity=".7"/>
 <!-- Nose bridge, soft broad tip and nostrils. -->
 <path d="M499 283 Q487 323 484 354 C483 381 451 394 456 417 C461 439 488 452 518 450 Q557 453 572 424 C581 401 555 386 548 365 Q540 327 538 297" fill="url(#nose)" stroke="#607b4b" stroke-width="4"/>
 <path d="M508 305 Q502 351 499 373 Q480 390 479 404" fill="none" stroke="#d6d89a" stroke-width="7" opacity=".65"/>
 <path d="M477 415 Q484 399 497 413 M534 416 Q548 402 555 416" fill="none" stroke="#3e5b39" stroke-width="6"/>
 <path d="M491 432 Q519 444 544 430" fill="none" stroke="#c6cd8c" stroke-width="4"/>
 <path d="M473 349 Q463 370 455 375 M553 344 Q561 368 571 376" stroke="#748b50" stroke-width="3" fill="none"/>
 <!-- Cheek creases and a controlled knowing smile. -->
 <path d="M409 422 C396 440 393 459 401 474 M600 418 Q620 433 630 457" fill="none" stroke="#556f43" stroke-width="4"/>
 <path d="M416 428 Q407 447 409 457 M595 425 Q610 438 613 451" fill="none" stroke="#c0c987" stroke-width="3" opacity=".6"/>
 <path d="M391 474 Q430 461 469 473 Q531 491 614 457 Q624 454 635 459 C597 499 549 518 497 506 Q440 505 398 486Z" fill="#455b39"/>
 <path d="M401 478 Q445 480 490 487 Q553 497 623 464" fill="none" stroke="#253e2c" stroke-width="5"/>
 <path d="M406 488 Q458 516 500 514 Q566 525 607 489" fill="none" stroke="#b1bd7e" stroke-width="6" opacity=".7"/>
 <path d="M581 481 L591 466 L598 477 Q590 485 581 481Z" fill="#ddd2a4" stroke="#697444" stroke-width="2"/>
 <path d="M382 474 L393 480 M632 453 L639 446" stroke="#435d38" stroke-width="4"/>
 <path d="M458 539 Q509 559 559 538" fill="none" stroke="#6a834e" stroke-width="5"/>
 <path d="M470 531 Q512 545 550 531" fill="none" stroke="#c8cf8e" stroke-width="4" opacity=".65"/>
 <!-- Sparse forehead creases; retain broad clean light planes. -->
 <path d="M401 201 Q477 181 548 192 M428 222 Q490 210 559 219 M590 205 Q619 209 639 224" fill="none" stroke="#7f9457" stroke-width="3" opacity=".72"/>
 <path d="M407 197 Q478 179 546 188 M437 218 Q492 208 551 215" fill="none" stroke="#d6dca1" stroke-width="2.5" opacity=".65"/>
 <path d="M485 254 L491 278 M518 248 L517 272 M543 253 L536 278" stroke="#74874e" stroke-width="3"/>
 <path d="M345 378 L359 385 M342 392 L354 398 M674 379 L663 386" stroke="#cad096" stroke-width="3" opacity=".6"/>
</g>'''


def svg(body, width, height):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">{DEFS}{body}</svg>'


def desk_art():
    result = ['''<g stroke-linejoin="round" stroke-linecap="round">
    <!-- Rear supports, stretchers and substantial front legs. -->
    <path d="M273 424 L347 424 L322 848 L267 863Z M1194 424 L1268 424 L1274 863 L1219 848Z" fill="#302a22" stroke="#20271f" stroke-width="7"/>
    <path d="M236 770 L1299 770 L1295 827 L234 827Z" fill="url(#woodFront)" stroke="#20271f" stroke-width="6"/>
    <path d="M249 780 L1276 780" stroke="#977247" stroke-width="4"/>
    <path d="M161 437 L291 437 L280 944 L265 963 L174 963 L155 944Z M1245 437 L1375 437 L1381 944 L1362 963 L1271 963 L1256 944Z" fill="url(#woodLeg)" stroke="#222920" stroke-width="7"/>
    <path d="M178 470 L210 474 L210 928 L181 928Z M1265 474 L1297 470 L1320 929 L1282 929Z" fill="#886242" opacity=".52"/>
    <path d="M159 877 L284 877 L282 914 L157 914Z M1253 877 L1377 877 L1379 914 L1255 914Z" fill="url(#gold)" stroke="#4d4430" stroke-width="4"/>
    <path d="M158 933 L283 933 L279 960 L172 960 L156 943Z M1257 933 L1379 933 L1380 943 L1364 960 L1267 960Z" fill="#463d2b" stroke="#202820" stroke-width="3"/>
    <!-- Frame and recessed panel construction. -->
    <path d="M125 439 L1411 439 L1370 690 L166 690Z" fill="url(#woodFront)" stroke="#22291f" stroke-width="8"/>
    <path d="M187 491 L1349 491 L1334 657 L202 657Z" fill="#302920" stroke="#a27c4d" stroke-width="6"/>
    <path d="M205 507 L571 507 L568 640 L217 640Z M594 507 L947 507 L947 640 L594 640Z M970 507 L1330 507 L1320 640 L972 640Z" fill="url(#woodInset)" stroke="#6d5435" stroke-width="5"/>
    <path d="M205 507 L217 522 L557 522 L571 507 M594 507 L610 522 L931 522 L947 507 M970 507 L985 522 L1314 522 L1330 507" fill="#9b794e" opacity=".65"/>
    <path d="M214 640 L226 625 L554 625 L568 640 M594 640 L610 625 L931 625 L947 640 M972 640 L986 625 L1306 625 L1320 640" fill="#29281f" opacity=".7"/>
    <path d="M143 452 L1395 452 L1390 475 L146 475Z" fill="#967248" stroke="#312b22" stroke-width="3"/>
    <path d="M176 677 L1360 677" stroke="#997347" stroke-width="4"/>
    <!-- Solid tabletop, flat upper plane and front thickness. -->
    <path d="M240 270 L1296 270 L1450 410 L86 410Z" fill="url(#woodTop)" stroke="#22291f" stroke-width="8"/>
    <path d="M86 410 L1450 410 L1440 452 L98 452Z" fill="url(#woodFront)" stroke="#22291f" stroke-width="7"/>
    <path d="M107 416 L1429 416" stroke="#d0ac72" stroke-width="6"/>
    <path d="M98 441 L1440 441" stroke="#362e22" stroke-width="5"/>
    <path d="M250 281 L1287 281 L1417 396 L120 396Z" fill="none" stroke="#b29260" stroke-width="3" opacity=".7"/>
    <path d="M279 280 L175 398 M512 280 L461 398 M745 280 L747 398 M978 280 L1033 398 M1211 280 L1319 398" stroke="#493727" stroke-width="3" opacity=".7"/>
    <path d="M278 284 L179 394 M513 285 L465 394 M749 284 L751 394 M980 284 L1037 394" stroke="#b5905e" stroke-width="2" opacity=".42"/>
    <!-- Restrained corner protection. -->
    <path d="M104 401 L184 401 L166 417 L166 465 L124 465 L126 429 L103 429Z M1432 401 L1352 401 L1370 417 L1370 465 L1412 465 L1410 429 L1433 429Z" fill="url(#gold)" stroke="#4b432d" stroke-width="4"/>
    <path d="M218 287 L246 275 L307 275 L296 286 L252 286 L242 296Z M1318 287 L1290 275 L1229 275 L1240 286 L1284 286 L1294 296Z" fill="url(#gold)" stroke="#5f4d30" stroke-width="3"/>
    <!-- Modest central geometric brass inlay. -->
    <path d="M768 546 L801 574 L768 602 L735 574Z" fill="#342e23" stroke="#b29661" stroke-width="5"/>
    <path d="M768 556 L787 574 L768 591 L750 574Z M751 574 L786 574 M768 558 L768 590" fill="none" stroke="#826c43" stroke-width="3"/>
    </g>''']
    # Sparse, deterministic broad wood grain; never random noise.
    result.append('<g fill="none" stroke-linecap="round">')
    for i in range(8):
        x = 240 + i * 134
        y = 315 + (i % 3) * 22
        result.append(f'<path d="M{x} {y} q37 -7 69 0 t64 -2" stroke="#382e24" stroke-width="2.2" opacity=".31"/>')
    for x in [253, 340, 434, 1070, 1170, 1250]:
        result.append(f'<path d="M{x} 538 q-12 19 3 42 t-2 28" stroke="#241f1b" stroke-width="2" opacity=".32"/>')
    result.append('</g>')
    # Screws with light and shadow, rather than tiny symbol-like noise.
    for x, y in [(145, 442), (1391, 442), (256, 282), (1280, 282), (178, 895), (265, 895), (1272, 895), (1359, 895)]:
        result.append(f'<circle cx="{x}" cy="{y}" r="5" fill="#514831" stroke="#dcc08a" stroke-width="1.8"/><path d="M{x-2} {y-2} L{x+2} {y+2}" stroke="#292a21" stroke-width="2"/>')
    result.append('''<g stroke-linejoin="round" stroke-linecap="round">
    <!-- Papers and a closed ledger, kept away from the hand contact area. -->
    <path d="M276 366 L520 342 L542 374 L296 397Z" fill="#342d22" opacity=".3"/>
    <path d="M255 333 L463 315 L517 367 L294 388Z" fill="url(#paper)" stroke="#7e7254" stroke-width="3"/>
    <path d="M274 326 L481 316 L526 363 L305 380Z" fill="url(#paper)" stroke="#7e7254" stroke-width="3"/>
    <path d="M320 337 L433 329 M330 350 L462 340" stroke="#9c9170" stroke-width="2" opacity=".4"/>
    <path d="M269 278 L439 269 L490 320 L492 351 L308 368 L269 332Z" fill="#1d3028" stroke="#252b22" stroke-width="5"/>
    <path d="M281 313 L442 299 L480 329 L480 346 L309 360 L281 332Z" fill="url(#paper)" stroke="#8c825d" stroke-width="2"/>
    <path d="M303 342 L474 331 M306 348 L477 337 M310 354 L478 343" stroke="#ac9a70" stroke-width="2"/>
    <path d="M269 278 L439 269 L492 318 L306 336Z" fill="url(#leather)" stroke="#a99762" stroke-width="4"/>
    <path d="M285 284 L431 278 L474 313 L314 327Z" fill="none" stroke="#91a17a" stroke-width="2"/>
    <path d="M362 286 L402 285 L438 316 L394 320Z" fill="#2a4234" stroke="#a38c56" stroke-width="2"/>
    <path d="M383 293 L404 304 L393 312 L374 302Z" fill="none" stroke="#a69967" stroke-width="2"/>
    <path d="M286 296 L317 325 L317 351" fill="none" stroke="#858d67" stroke-width="3"/>
    </g>''')
    # Small coin groups at the far side of the counter.
    for cx, cy, count in [(1150, 348, 5), (1210, 366, 3), (1114, 378, 1), (1261, 356, 1)]:
        result.append(f'<ellipse cx="{cx+2}" cy="{cy+6}" rx="34" ry="12" fill="#201f18" opacity=".32"/>')
        for level in range(count):
            yy = cy - level * 7
            result.append(f'<path d="M{cx-26} {yy-3}v7c0 14 52 14 52 0v-7" fill="url(#gold)" stroke="#66532f" stroke-width="2"/>')
            result.append(f'<ellipse cx="{cx}" cy="{yy-3}" rx="26" ry="9" fill="#d1b575" stroke="#806235" stroke-width="2"/>')
        yy = cy - (count - 1) * 7 - 3
        result.append(f'<ellipse cx="{cx}" cy="{yy}" rx="17" ry="5.5" fill="none" stroke="#a48546" stroke-width="2"/><path d="M{cx-5} {yy}l5 -3 5 3 -5 3Z" fill="#9d7f41"/>')
    return ''.join(result)


def font(size, bold=False):
    return ImageFont.truetype('C:/Windows/Fonts/msyhbd.ttc' if bold else 'C:/Windows/Fonts/msyh.ttc', size)


def place_contained(canvas, asset, box, pad=16):
    image = asset.crop(asset.getbbox())
    x, y, w, h = box
    image.thumbnail((w - pad * 2, h - pad * 2), Image.Resampling.LANCZOS)
    canvas.alpha_composite(image, (x + (w-image.width)//2, y + (h-image.height)//2))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--renderer-dir', type=Path)
    args = parser.parse_args()
    if args.renderer_dir:
        sys.path.insert(0, str(args.renderer_dir))
    import resvg_py
    OUT.mkdir(parents=True, exist_ok=True)
    assets = {}
    for name, body, w, h in [('goblin', CHARACTER+HANDS, 1024, 1024), ('desk', desk_art(), 1536, 1024)]:
        markup = svg(body, w, h)
        (OUT / f'{name}.svg').write_text(markup, encoding='utf-8')
        data = resvg_py.svg_to_bytes(svg_string=markup, skip_system_fonts=True)
        (OUT / f'{name}.png').write_bytes(data)
        assets[name] = Image.open(io.BytesIO(data)).convert('RGBA')
    hands = Image.open(io.BytesIO(resvg_py.svg_to_bytes(svg_string=svg(HANDS,1024,1024), skip_system_fonts=True))).convert('RGBA')
    combined = Image.new('RGBA', (1536,1536))
    combined.alpha_composite(assets['goblin'],(256,0))
    combined.alpha_composite(assets['desk'],(0,500))
    combined.alpha_composite(hands,(256,0))
    combined.save(OUT/'combined.png')
    board = Image.new('RGBA',(2400,1360),'#202922')
    d = ImageDraw.Draw(board)
    d.text((70,42),'哥布林银行 · 高分辨率试绘',font=font(48,True),fill='#e8dfc5')
    d.text((72,111),'当前模型绘图代码渲染  /  独立原稿  /  尚未像素化',font=font(24),fill='#9da88d')
    for x,title in [(48,'01  哥布林 · 单张待机'),(824,'02  木质柜台 · 独立素材'),(1600,'03  坐姿与桌面 · 组合')]:
        d.rounded_rectangle((x,182,x+752,1288),radius=14,fill='#2c352c',outline='#515844',width=2)
        d.text((x+30,208),title,font=font(29,True),fill='#d5c696')
    place_contained(board,assets['goblin'],(64,294,720,884))
    place_contained(board,assets['desk'],(840,368,720,700))
    place_contained(board,combined,(1616,310,720,910))
    d.text((80,1222),'1024 × 1024  /  透明 PNG',font=font(23),fill='#a3ae96')
    d.text((856,1222),'1536 × 1024  /  透明 PNG',font=font(23),fill='#a3ae96')
    d.text((1632,1222),'角色、桌子分层  /  手部覆盖桌面',font=font(23),fill='#a3ae96')
    board.convert('RGB').save(OUT/'review.png')
    report = {'method':'model-authored Bezier/gradient illustration, rasterized with resvg; no image-generation API',
              'stage':'high-resolution review only; no pixelation or game replacement', 'assets':{}}
    for name in ['goblin','desk','combined']:
        im=Image.open(OUT/f'{name}.png')
        alpha=im.getchannel('A')
        assert im.mode=='RGBA' and alpha.getextrema()==(0,255)
        box=im.getbbox()
        assert box and box[0]>0 and box[1]>0 and box[2]<im.width and box[3]<im.height
        report['assets'][name]={'size':list(im.size),'alpha_bbox':list(box)}
    (OUT/'render_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report))


if __name__=='__main__':
    main()
